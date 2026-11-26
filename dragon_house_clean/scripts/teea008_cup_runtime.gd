extends RefCounted
## Cup possession uses the existing event reducer. Review mugs are NOT
## canonical personal possessions. No beverage/fill state is inferred.
var world
var nav
const Beverages=preload("res://scripts/canonical_beverage_runtime.gd")
var beverages=Beverages.new()

func setup(model,navigation)->void:
	world=model
	nav=navigation
	beverages.setup(world)

func register_review_mugs()->int:
	var rooms:Array=[]
	if world.canonical_house_seed:
		rooms=world.matching_rooms(["common","rest","kitchen"])
	else:
		rooms=[world.get_room(-2,0)]
	var added:=0
	for room in rooms:
		if room.is_empty():continue
		var row:Dictionary=nav.layouts.get(nav.key(room),{})
		for item in row.get("instances",[]):
			var asset:String=str(item.get("asset_id",""))
			if not asset in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:continue
			var id:String="TEEA008_REVIEW_"+asset
			if str(room["type"])!="common":
				id="SOCIAL_REVIEW_"+str(room["id"])+"_"+str(item["instance_id"])
			if not world.physical_object(id).is_empty():continue
			var pos:Array=item["room_local_xyz"]
			var meta:Dictionary={"asset_id":asset,"viewer_category":"cups","object_class":"display_object","home_anchor":[pos[0],pos[2]],"display_world_height":0.105,"description":"Проверочная чашка; владелец не назначен; не канонический предмет.","reset_eligible":true}
			var title:String="Красная чашка · кандидат" if asset.ends_with("_red") else "Синяя чашка · кандидат"
			if world.register_physical_object(id,title,"",str(room["id"]),true,true,false,false,true,meta):
				added+=1
	return added

func reserved(ignore:String="")->Dictionary:
	var result:Dictionary={}
	for id in world.residents:
		if str(id)==ignore:continue
		var actor:Dictionary=world.residents[id]
		if str(actor.get("cup_task_stage","")) in ["fetch","serve","hold"]:
			result[str(actor.get("cup_task_id",""))]=str(id)
	return result

func candidates(actor:Dictionary,room:Dictionary)->Array:
	var result:Array=[]
	var used:=reserved(str(actor["id"]))
	for id in world.objects:
		var obj:Dictionary=world.objects[id]
		var owner:String=str(obj.get("canonical_owner_id",""))
		if str(obj.get("viewer_category",""))!="cups" or str(obj.get("current_room_id",""))!=str(room.get("id","")) or str(obj.get("state",""))!="PLACED" or str(obj.get("current_holder_id",""))!="" or not bool(obj.get("movable",false)) or used.has(str(id)):
			continue
		if owner!="" and owner!=str(actor["id"]):
			continue
		if beverages.enabled and not beverages.can_use(str(id),str(actor["id"])):continue
		var slot:Dictionary=slot_for_object(obj)
		if not slot.is_empty():
			result.append({"object_id":str(id),"slot":slot})
	if beverages.enabled:
		result.sort_custom(func(a,b):return float(beverages.content(str(a["object_id"])).get("remaining_ml",0))>float(beverages.content(str(b["object_id"])).get("remaining_ml",0)))
	return result

func slot_for_object(obj:Dictionary)->Dictionary:
	var room:Dictionary=world.room_by_id(str(obj.get("current_room_id","")))
	var raw:Array=obj.get("current_anchor",[])
	if room.is_empty() or raw.size()!=2:
		return {}
	var p:=Vector2(float(raw[0]),float(raw[1]))
	for slot in nav.cup_slots(room):
		var pos:Array=slot["xyz"]
		if p.distance_to(Vector2(float(pos[0]),float(pos[2])))<0.06:
			return slot
	return {}

func pickup(actor:Dictionary)->bool:
	var id:String=str(actor.get("cup_task_id",""))
	var obj:Dictionary=world.physical_object(id)
	var room_id:String=str(actor.get("cup_task_room",""))
	var slot:Dictionary=slot_for_object(obj)
	if slot.is_empty() or str(slot.get("id",""))!=str(actor.get("cup_task_slot","")) or str(actor.get("room_id",""))!=room_id or str(actor.get("station_room_id",""))!=room_id or str(actor.get("station_anchor_id",""))!=str(slot["id"]) or str(actor.get("phase",""))!="perform":
		return false
	if reserved(str(actor["id"])).has(id):
		return false
	if beverages.enabled and not beverages.can_use(id,str(actor["id"])):return false
	if beverages.enabled and not at_approach(actor,world.room_by_id(room_id),slot["approach"]):return false
	var owner:String=str(obj.get("canonical_owner_id",""))
	if owner!="" and owner!=str(actor["id"]):
		return false
	return world.pickup_physical_object(id,str(actor["id"]))

func put_back(actor:Dictionary)->bool:
	var id:String=str(actor.get("cup_task_id",""))
	var room_id:String=str(actor.get("cup_task_room",""))
	if str(actor.get("room_id",""))!=room_id or str(actor.get("station_room_id",""))!=room_id or str(actor.get("station_anchor_id",""))!=str(actor.get("cup_task_slot","")) or str(actor.get("phase",""))!="perform":
		return false
	var room:Dictionary=world.room_by_id(room_id)
	for slot in nav.cup_slots(room):
		if str(slot["id"])==str(actor["cup_task_slot"]):
			if beverages.enabled and not at_approach(actor,room,slot["approach"]):return false
			var pos:Array=slot["xyz"]
			if not world.housekeeping_slot_free(world.physical_object(id),room_id,[pos[0],pos[2]],str(slot["id"])):return false
			return world.place_physical_object(id,str(actor["id"]),room_id,"PLACED",[float(pos[0]),float(pos[2])])
	return false

func at_approach(actor:Dictionary,room:Dictionary,offset:Vector2)->bool:
	if room.is_empty():return false
	var local:Vector2=world.room_world_to_local(room,Vector3(float(actor.get("x",0)),float(actor.get("visual_y",0)),float(actor.get("z",0))))
	return local.distance_to(offset)<0.10

func service_sources(actor:Dictionary,room:Dictionary)->Array:
	var result:Array=[]
	var occupied:Dictionary={}
	for other in world.residents.values():
		if str(other.get("id",""))!=str(actor["id"]) and str(other.get("cup_task_room",""))==str(room["id"]):
			var sid:String=str(other.get("drink_service_id",""))
			if sid!="":occupied[sid]=true
	var row:Dictionary=nav.layouts.get(nav.key(room),{})
	var items:Dictionary={}
	for item in row.get("instances",[]):items[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		var id:String=str(item["instance_id"])
		var source:=""
		var support:Dictionary=item
		if str(item["asset_id"])=="sketchfab_steampunk_coffee_machine":
			source="COFFEE_NOOK"
			support=items.get(str(item.get("support_ref","")).get_slice(".",0),{})
		elif id.ends_with("_bar_counter"):
			source="BAR"
		if source=="" or support.is_empty() or occupied.has(id):continue
		var lo:Array=support["bounds_min_m"]
		var hi:Array=support["bounds_max_m"]
		var pos:Array=item["room_local_xyz"]
		var approach_options:Array=[Vector2(float(pos[0]),float(hi[2])+0.38),Vector2(float(lo[0])-0.38,float(pos[2])),Vector2(float(hi[0])+0.38,float(pos[2])),Vector2(float(pos[0]),float(lo[2])-0.38)]
		# A chair can block the centre of a real bar without blocking the
		# entire service edge. Sample the measured counter perimeter before
		# declaring the source unavailable. Do not move furniture or shrink
		# the navigation clearance to obtain a service point.
		if source=="BAR":
			for fraction in [0.25,0.75,0.1,0.9,0.0,1.0]:
				var edge_x:float=lerpf(float(lo[0]),float(hi[0]),float(fraction))
				var edge_z:float=lerpf(float(lo[2]),float(hi[2]),float(fraction))
				approach_options.append(Vector2(edge_x,float(hi[2])+0.38))
				approach_options.append(Vector2(float(lo[0])-0.38,edge_z))
				approach_options.append(Vector2(float(hi[0])+0.38,edge_z))
		var aisle:=Vector2(-float(room.get("size_modules",1))*2.4+0.08,1.50)
		for approach in approach_options:
			if nav.clear(room,approach) and not nav.path(room,aisle,approach).is_empty():
				result.append({"id":id,"type":source,"approach":approach})
				break
	return result
