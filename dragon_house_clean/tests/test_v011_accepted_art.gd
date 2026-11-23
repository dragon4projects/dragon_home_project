extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _ids(items:Array)->Array:
	var out:Array=[]
	for item in items:
		out.append(str(item.get("id","")))
	return out

func _active_anchor_ids(scene,room:Dictionary)->Array:
	if room.is_empty():
		return []
	var group:Dictionary=scene.world.merged_group(int(room["x"]),int(room["level"]))
	var module_index:=-1
	for i in range(group["cells"].size()):
		if str(group["cells"][i]["id"])==str(room["id"]):
			module_index=i
			break
	return _ids(scene.life.stations.furniture.for_room_variant(
		room,int(group.get("width",1)),module_index))

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene

	assert(scene.interior_skin.validated_layers("common",3).size()==4)
	assert(scene.interior_skin.validated_layers("library",2).size()==4)
	assert(scene.interior_skin.validated_layers("study",1).size()==3)
	assert(scene.interior_skin.validated_layers("rest",1).size()==4)
	assert(scene.interior_skin.validated_layers("private",1).is_empty())

	var common_left=scene.world.get_room(-2,0)
	var common_mid=scene.world.get_room(-1,0)
	var common_right=scene.world.get_room(0,0)
	assert(_active_anchor_ids(scene,common_left)==[
		"common_sofa_left_seat_a","common_sofa_left_seat_b"])
	assert(_active_anchor_ids(scene,common_mid).is_empty())
	assert(_active_anchor_ids(scene,common_right)==[
		"common_bench_right_seat_a","common_chair_right_seat_a"])
	assert(not _ids(scene.life.stations.furniture.for_room(common_left)).has(
		"common_chair_left_seat_a"))
	assert(_active_anchor_ids(scene,scene.world.get_room(-3,0))==[
		"study_chair_work"])
	# Library art accepted by owner is R2-only. The seeded house still has a
	# single Library R1, so its live interaction contract must remain the
	# procedural TABLE_LIBRARY pair until a real R2 merge exists.
	var library_r1=scene.world.get_room(2,0)
	assert(int(scene.world.merged_group(2,0)["width"])==1)
	assert(_active_anchor_ids(scene,library_r1)==[
		"table_left","table_right"])
	assert(_active_anchor_ids(scene,scene.world.get_room(1,0))==[
		"rest_sofa_seat_a","rest_sofa_seat_b","rest_lounge_seat_a"])

	scene.selected_room=common_left["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=13.3
	scene.zoom=13.3
	scene.apply_camera(0.1)
	scene.update_render_lod()

	var group=scene.world.merged_group(-1,0)
	var node:Node3D=scene.room_root.get_node(group["primary_id"])
	var art:Node3D=node.get_node("Layer_ApprovedArt")
	assert(art.get_child_count()==4)
	assert(not node.get_node("Layer_Background/Stage_Backwall").visible)
	var fg:Sprite3D=art.get_node("Art_foreground")
	assert(fg.has_meta("physical_z"))
	assert(is_equal_approx(float(fg.get_meta("physical_z")),-0.4711))
	var reference:Sprite3D=art.get_node("Art_furniture_back")
	var camera_local:Vector3=node.to_local(scene.camera.global_position)
	var k:float=(float(fg.get_meta("physical_z"))-camera_local.z)/(
		reference.position.z-camera_local.z)
	assert(is_equal_approx(fg.scale.x,k))
	assert(float(fg.get_meta("physical_z"))<0.95)

	print("DRAGON_V011_ACCEPTED_ART_PASS layers=15 measured_stations=10 blocked_excluded foreground_registered=true")
	quit(0)
