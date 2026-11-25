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
var waiting:=0
var boarded:=0
var peak:=0
var legacy_drains:=0

func setup(model)->void:
	world=model
	sync()

func _vertical(actor:Dictionary)->bool:
	if not bool(actor.get("active",false)) or str(actor.get("phase",""))!="travel":return false
	var points:Array=actor.get("waypoints",[])
	var i:int=int(actor.get("waypoint_index",0))
	return i>=0 and i<points.size() and str(points[i].get("kind",""))=="lift"

func _shaft(actor:Dictionary)->String:
	var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
	return str(room["x"]) if str(room.get("type",""))=="lift" else ""

func _in_air(actor:Dictionary)->bool:
	var y:float=float(actor.get("visual_y",0))
	return absf(y-roundf(y/world.FLOOR_H)*world.FLOOR_H)>0.035

func sync()->void:
	occupied.clear()
	legacy.clear()
	if world==null:return
	for collection in [world.residents,world.creatures]:
		for actor in collection.values():
			if not _vertical(actor):
				actor.erase("canonical_lift_slot")
				actor.erase("canonical_lift_boarded")
				continue
			var shaft:=_shaft(actor)
			if shaft=="":continue
			var row:Dictionary=actor.get("canonical_lift_slot",{})
			var slot:int=int(row.get("index",-1))
			var holders:Dictionary=occupied.get(shaft,{})
			if str(row.get("shaft",""))==shaft and slot>=0 and slot<CAPACITY and not holders.has(slot):
				holders[slot]=str(actor["id"])
				occupied[shaft]=holders
				peak=maxi(peak,holders.size())
			else:
				actor.erase("canonical_lift_slot")
				actor.erase("canonical_lift_boarded")
				if _in_air(actor):
					legacy[shaft]=int(legacy.get(shaft,0))+1

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
		if int(legacy.get(shaft,0))>0 or holders.size()>=CAPACITY:
			waiting+=1
			return {"target":at,"wait":true}
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
