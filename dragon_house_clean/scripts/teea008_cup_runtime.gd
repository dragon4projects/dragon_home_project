extends RefCounted
## Cup possession uses the existing event reducer. Review mugs are NOT
## canonical personal possessions. No beverage/fill state is inferred.
var world
var nav

func setup(model,navigation)->void:
	world=model
	nav=navigation

func register_review_mugs()->int:
	var room:Dictionary=world.get_room(-2,0)
	if str(room.get("type",""))!="common" or int(room.get("size_modules",1))!=3:
		return 0
	var row:Dictionary=nav.layouts.get(nav.key(room),{})
	var added:=0
	for item in row.get("instances",[]):
		var asset:String=str(item.get("asset_id",""))
		if not asset in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:
			continue
		var id:String="TEEA008_REVIEW_"+asset
		if not world.physical_object(id).is_empty():
			continue
		var pos:Array=item["room_local_xyz"]
		var meta:Dictionary={"asset_id":asset,"viewer_category":"cups","object_class":"display_object","home_anchor":[pos[0],pos[2]],"display_world_height":0.105,"description":"Проверочная чашка TEEA008; владелец не назначен; не канонический предмет.","reset_eligible":true}
		var title:String="Красная чашка · кандидат" if asset.ends_with("_red") else "Синяя чашка · кандидат"
		if world.register_physical_object(id,title,"",str(room["id"]),true,true,false,false,true,meta):
			added+=1
	return added

func reserved(ignore:String="")->Dictionary:
	var result:Dictionary={}
	for id in world.residents:
		if str(id)==ignore:continue
		var actor:Dictionary=world.residents[id]
		if str(actor.get("cup_task_stage","")) in ["fetch","hold"]:
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
		var slot:Dictionary=slot_for_object(obj)
		if not slot.is_empty():
			result.append({"object_id":str(id),"slot":slot})
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
			var pos:Array=slot["xyz"]
			return world.place_physical_object(id,str(actor["id"]),room_id,"PLACED",[float(pos[0]),float(pos[2])])
	return false
