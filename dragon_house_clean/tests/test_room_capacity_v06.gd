extends SceneTree
## A 49-cell future house must keep semantic LOD bounded.
## v0.19 contract: HOUSE/LEVEL never materialize rich furniture merely because
## numeric zoom is close; rich detail belongs to ROOM/FOLLOW only.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_49_room_lod_v06.json"
	root.add_child(scene)
	current_scene=scene
	var world=scene.world
	var added:=0
	for level in [-2,2]:
		for x in range(-7,7):
			if world.get_room(x,level).is_empty():
				var choices:=["corridor","library","rest","music","study","cinema","workshop"]
				world.make_room(x,level,choices[posmod(x+7,choices.size())])
				added+=1
	assert(world.rooms.size()==49,"Synthetic 49-cell world")
	scene.make_rooms()
	await process_frame
	await process_frame

	# HOUSE is semantic overview, independent of numeric zoom.
	scene.set_mode("HOUSE")
	scene.zoom_current=100.0
	scene.zoom=100.0
	scene.smooth_focus=Vector3.ZERO
	scene.update_render_lod()
	await process_frame
	await process_frame
	assert(scene.detailed_room_groups.size()==0,"HOUSE overview must keep rich furniture evicted")
	var group_count:int=scene.room_root.get_child_count()
	assert(group_count>=30,"No room shell lost when growing house")

	scene.zoom_current=10.0
	scene.zoom=10.0
	scene.update_render_lod()
	assert(scene.detailed_room_groups.size()==0,
		"HOUSE close zoom must remain proxy-only; semantic mode owns detail")

	# LEVEL is also cheap even on a close numeric zoom.
	scene.select_level(0)
	scene.zoom_current=10.0
	scene.zoom=10.0
	scene.update_render_lod()
	assert(scene.current_mode=="LEVEL")
	assert(scene.detailed_room_groups.size()==0,
		"LEVEL close zoom must remain proxy-only")

	# ROOM materializes only a bounded local set.
	var common:Dictionary=world.get_room(-1,0)
	scene.selected_room=str(common["id"])
	scene.set_mode("ROOM")
	scene.smooth_focus=Vector3(float(common["x"])*scene.W,float(common["level"])*scene.H+1.45,0.0)
	scene.zoom_current=scene.zoom
	scene.update_render_lod()
	var instanced:int=scene.detailed_room_groups.size()
	assert(instanced>0 and instanced<17,
		"ROOM materialization bounded independent of total house size")

	scene.set_mode("HOUSE")
	scene.zoom_current=100.0
	scene.zoom=100.0
	scene.update_render_lod()
	assert(scene.detailed_room_groups.size()==0)

	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	print("ROOM_CAPACITY_V019_PASS rooms=%d visual_groups=%d house_near=0 level_near=0 room_instanced=%d" %
		[world.rooms.size(),group_count,instanced])
	quit(0)
