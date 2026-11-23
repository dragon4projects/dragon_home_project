extends SceneTree
## Verify low-memory cutaway materialization and private-room denial on both zooms.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_lazy_cutaway_v06.json"
	root.add_child(scene)
	current_scene=scene
	# Wide HOUSE frame: room shell/cues visible but no rich furniture instantiated.
	scene.current_mode="HOUSE"
	scene.zoom_current=86.0
	scene.smooth_focus=Vector3.ZERO
	scene.update_render_lod()
	await process_frame
	await process_frame
	assert(scene.detailed_room_groups.size()==0,"HOUSE overview must evict all rich furniture")
	var cue_count := 0
	for node in scene.room_root.get_children():
		var cue: Node3D=node.get_node_or_null("Layer_OverviewCues")
		var rich: Node3D=node.get_node_or_null("LocalFurniture")
		var typ: String=str(scene.visual_room_groups.get(node.name,{}).get("type",""))
		var stage: Node3D=node.get_node_or_null("Layer_Background/Stage_Backwall")
		if typ=="private":
			assert(cue==null and rich==null and stage==null,
				"Private room has facade, never backwall scene or furniture")
		else:
			if typ!="lift":
				assert(stage!=null,"Public room requires a modeled rear alcove")
				assert(stage.get_child_count()==int(scene.visual_room_groups[node.name]["width"]),
					"R1/R2/R3 must use exactly one rear bay per cell")
				assert(not stage.visible,
					"HOUSE overview must hide unreadable rear-stage geometry")
			assert(cue!=null and cue.visible and rich!=null)
			assert(rich.get_child_count()==0,"Rich furniture must not be spawned on HOUSE overview")
			cue_count+=1
	assert(cue_count>8)
	var library: Dictionary=scene.world.get_room(2,0)
	scene.smooth_focus=Vector3(2.0*scene.W,0,0)
	scene.zoom_current=17.0
	scene.current_mode="ROOM"
	scene.update_render_lod()
	assert(scene.detailed_room_groups.size()>=1,"Near camera must instantiate rich details")
	var library_group: Dictionary=scene.world.merged_group(2,0)
	var library_node: Node3D=scene.room_root.get_node(library_group["primary_id"])
	assert(scene.detailed_room_groups.has(library_node.name))
	assert(library_node.get_node("Layer_Structure/Stage_CutawayDepth").visible,
		"ROOM view must restore physical cutaway depth")
	assert(library_node.get_node("Layer_Background/Stage_Backwall").visible,
		"Procedural Library R1 must restore its rear alcove near the camera")
	var detailed: Node3D=library_node.get_node("LocalFurniture")
	assert(detailed.get_child_count()>0)
	assert(not library_node.get_node("Layer_OverviewCues").visible,
		"Overview proxy cannot overlap rich detail")
	var count_first:int=scene.detail_materialization_count
	scene.update_render_lod()
	assert(scene.detail_materialization_count==count_first,
		"Repeated near frame cannot duplicate the furniture tree")
	scene.zoom_current=86.0
	scene.update_render_lod()
	assert(scene.detailed_room_groups.is_empty(),"Away-from-camera detail evicted")
	await process_frame
	await process_frame
	assert(detailed.get_child_count()==0)
	assert(library_node.get_node("Layer_OverviewCues").visible)
	# Close selection of private rooms must reveal no extra nodes.
	scene.smooth_focus=Vector3(3.0*scene.W,scene.H,0.0)
	scene.zoom_current=10.0
	scene.update_render_lod()
	var private_id: String=scene.world.get_room(3,1)["id"]
	assert(not scene.detailed_room_groups.has(private_id))
	var private_node: Node3D=scene.room_root.get_node(private_id)
	assert(private_node.get_node_or_null("LocalFurniture")==null)
	assert(private_node.get_node_or_null("Layer_OverviewCues")==null)
	var first_actor: Dictionary=scene.world.residents["RES_01"]
	# The sprite's feet anchor must survive the renderer; never overwritten by generic 1.05.
	var resident_sprite: Sprite3D=scene.actor_sprites["RES_01"].get_node("Body")
	if first_actor.get("runtime_visual_bound",false):
		assert(resident_sprite.position.y!=1.05,
			"Imported artist-defined anchor must not be overwritten")
	print("ROOM_LOD_V06_PASS overview=%d near=%d unload=%d private=blocked anchor=preserved" % [
		cue_count,count_first,scene.detail_eviction_count])
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	quit(0)

