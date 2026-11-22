extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_cursor_zoom_v06.json"
	root.add_child(scene)
	current_scene=scene
	scene.set_mode("HOUSE")
	scene.apply_camera(0.15)
	var mouse:=Vector2(770,390)
	var hit=scene.ray_to_front_plane(mouse)
	assert(hit!=null)
	var before: Vector3=scene.desired_focus
	var old_zoom: float=scene.zoom
	scene.zoom_around_pointer(mouse,0.80)
	assert(is_equal_approx(scene.zoom,old_zoom*0.80))
	var expected_x:float=float(hit.x)-(float(hit.x)-before.x)*0.80
	var expected_y:float=float(hit.y)-(float(hit.y)-before.y)*0.80
	assert(absf(scene.desired_focus.x-expected_x)<0.0001)
	assert(absf(scene.desired_focus.y-expected_y)<0.0001)
	# Reversing factor with identical anchor mathematically reverts the move.
	var after: Vector3=scene.desired_focus
	scene.zoom_around_pointer(mouse,1.25)
	assert(scene.zoom>old_zoom*0.99)
	assert(not is_equal_approx(after.x,before.x))
	# Following a real actor still allows wheel zoom, but never changes focus via pointer.
	scene.follow_actor("MANJKA")
	var follow_focus: Vector3=scene.desired_focus
	var follow_zoom:float=scene.zoom
	scene.zoom_around_pointer(mouse,0.87)
	assert(scene.follow_id=="MANJKA")
	assert(scene.zoom<follow_zoom)
	assert(scene.desired_focus.is_equal_approx(follow_focus))
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	print("CURSOR_ZOOM_V06_PASS pointer_anchored=true follow_retained=true")
	quit(0)

