extends RefCounted
## Six independent rider slots per physical shaft. Capacity is shared across
## residents and ambient creatures. The shaft is not a simulated single cabin.
## Slot assignment persists on the actor; old centerline trips drain unchanged.
const CAPACITY:=6
const SLOT_X:=0.52
const LANES:=[-0.75,0.0,0.75]
var world
var occupied:Dictionary={}
var legacy:Dictionary={}
# Per-shaft FIFO tickets survive checkpoints. A newly arriving actor must
# not steal a released slot before an older waiter is stepped.
var queues:Dictionary={}
var queue_serial:int=0
var waiting:=0
var boarded:=0
var peak:=0
var legacy_drains:=0

func setup(model)->void:
	world=model
	queue_serial=int(world.runtime_state.get("lift_queue_serial",0))
	sync()

func _vertical(actor:Dictionary)->bool:
	if not bool(actor.get("active",false)) or str(actor.get("phase",""))!="travel":return false
	var points:Array=actor.get("waypoints",[])
	var i:int=int(actor.get("waypoint_index",0))
	return i>=0 and i<points.size() and str(points[i].get("kind",""))=="lift"

func _shaft(actor:Dictionary)->String:
	var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
	return str(int(room["x"])) if str(room.get("type",""))=="lift" else ""

# JSON restores integral room coordinates as floats. Accept the historical
# integral-float spelling, but never a fractional or invalid shaft identity.
func _same_shaft(raw:String,shaft:String)->bool:
	return shaft!="" and raw.is_valid_float() and is_finite(float(raw)) and float(raw)==float(shaft)

func _in_air(actor:Dictionary)->bool:
	var y:float=float(actor.get("visual_y",0))
	return absf(y-roundf(y/world.FLOOR_H)*world.FLOOR_H)>0.035

func sync()->void:
	occupied.clear()
	legacy.clear()
	queues.clear()
	if world==null:return
	for collection in [world.residents,world.creatures]:
		for actor in collection.values():
			if not _vertical(actor):
				actor.erase("canonical_lift_slot")
				actor.erase("canonical_lift_boarded")
				actor.erase("canonical_lift_wait")
				continue
			var shaft:=_shaft(actor)
			if shaft=="":
				actor.erase("canonical_lift_wait")
				continue
			var row:Dictionary=actor.get("canonical_lift_slot",{})
			var slot:int=int(row.get("index",-1))
			var holders:Dictionary=occupied.get(shaft,{})
			if _same_shaft(str(row.get("shaft","")),shaft) and slot>=0 and slot<CAPACITY and not holders.has(slot):
				actor["canonical_lift_slot"]={"shaft":shaft,"index":slot}
				actor.erase("canonical_lift_wait")
				holders[slot]=str(actor["id"])
				occupied[shaft]=holders
				peak=maxi(peak,holders.size())
			else:
				actor.erase("canonical_lift_slot")
				actor.erase("canonical_lift_boarded")
				if _in_air(actor):
					legacy[shaft]=int(legacy.get(shaft,0))+1
					actor.erase("canonical_lift_wait")
				else:
					var ticket:Dictionary=actor.get("canonical_lift_wait",{})
					var serial:int=int(ticket.get("serial",0))
					if _same_shaft(str(ticket.get("shaft","")),shaft) and serial>0 and (not world.residents.has(str(actor["id"])) or bool(actor.get("autonomy_enabled",true))):
						queue_serial=maxi(queue_serial,serial)
						var queue:Dictionary=queues.get(shaft,{})
						queue[str(actor["id"])]=serial
						queues[shaft]=queue
					else:actor.erase("canonical_lift_wait")
	world.runtime_state["lift_queue_serial"]=queue_serial

func _enqueue(actor:Dictionary,shaft:String)->void:
	var id:String=str(actor["id"])
	var queue:Dictionary=queues.get(shaft,{})
	if not queue.has(id):
		queue_serial+=1
		world.runtime_state["lift_queue_serial"]=queue_serial
		queue[id]=queue_serial
		queues[shaft]=queue
	actor["canonical_lift_wait"]={"shaft":shaft,"serial":queue[id]}

func _dequeue(actor:Dictionary)->void:
	var ticket:Dictionary=actor.get("canonical_lift_wait",{})
	var shaft:String=str(ticket.get("shaft",""))
	var queue:Dictionary=queues.get(shaft,{})
	queue.erase(str(actor["id"]))
	if queue.is_empty():queues.erase(shaft)
	actor.erase("canonical_lift_wait")

func _first_waiter(shaft:String)->String:
	var queue:Dictionary=queues.get(shaft,{})
	var first:String=""
	var serial:int=9223372036854775807
	for id in queue:
		var value:int=int(queue[id])
		if value<serial or (value==serial and (first=="" or str(id)<first)):
			first=str(id)
			serial=value
	return first

func slot_position(shaft:String,slot:int,y:float)->Vector3:
	return Vector3(float(shaft)*world.MODULE_W+(-SLOT_X if slot%2==0 else SLOT_X),y,float(LANES[slot/2]))

func target(actor:Dictionary,at:Vector3,authored:Vector3)->Dictionary:
	var shaft:=_shaft(actor)
	if shaft=="":return {"target":authored}
	var holders:Dictionary=occupied.get(shaft,{})
	var row:Dictionary=actor.get("canonical_lift_slot",{})
	var slot:int=int(row.get("index",-1))
	var id:String=str(actor["id"])
	if str(row.get("shaft",""))!=shaft or slot<0 or slot>=CAPACITY or str(holders.get(slot,""))!=id:
		if _in_air(actor):
			# Legacy save: never snap a character sideways between floors.
			legacy_drains+=1
			return {"target":authored,"legacy":true}
		if int(legacy.get(shaft,0))>0 or holders.size()>=CAPACITY or not queues.get(shaft,{}).is_empty():
			_enqueue(actor,shaft)
			if int(legacy.get(shaft,0))>0 or holders.size()>=CAPACITY or _first_waiter(shaft)!=id:
				waiting+=1
				return {"target":at,"wait":true}
		_dequeue(actor)
		slot=0
		while holders.has(slot):slot+=1
		holders[slot]=id
		occupied[shaft]=holders
		actor["canonical_lift_slot"]={"shaft":shaft,"index":slot}
		actor["canonical_lift_boarded"]=false
		boarded+=1
		peak=maxi(peak,holders.size())
	if not bool(actor.get("canonical_lift_boarded",false)):
		var boarding:=slot_position(shaft,slot,at.y)
		if at.distance_to(boarding)>0.025:
			return {"target":boarding,"boarding":true}
		actor["canonical_lift_boarded"]=true
	return {"target":slot_position(shaft,slot,authored.y)}

func release(actor:Dictionary)->void:
	_dequeue(actor)
	var row:Dictionary=actor.get("canonical_lift_slot",{})
	var shaft:String=str(row.get("shaft",""))
	var slot:int=int(row.get("index",-1))
	var holders:Dictionary=occupied.get(shaft,{})
	if str(holders.get(slot,""))==str(actor.get("id","")):
		holders.erase(slot)
	actor.erase("canonical_lift_slot")
	actor.erase("canonical_lift_boarded")

func metrics()->Dictionary:
	return {"capacity":CAPACITY,"peak":peak,"boarded":boarded,"wait_steps":waiting,"legacy_drain_steps":legacy_drains}
