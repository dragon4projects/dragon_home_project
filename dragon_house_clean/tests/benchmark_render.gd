extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var total_groups: int = scene.world.visual_groups().size()
	var scores: Array = []
	for mode in ["HOUSE","ROOM"]:
		if mode == "ROOM":
			scene.selected_room = scene.world.get_room(-1,0)["id"]
		scene.set_mode(mode)
		for warmup in range(25):
			await process_frame
		var start: int = Time.get_ticks_msec()
		var peak_draws: int = 0
		var peak_objects: int = 0
		for i in range(100):
			await process_frame
			peak_draws = maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			peak_objects = maxi(peak_objects,int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		var elapsed: int = Time.get_ticks_msec()-start
		var avg: float = 100000.0 / maxf(1.0,float(elapsed))
		var record: Dictionary = {"mode":mode,"fps_approx":snappedf(avg,0.1),"draw_calls_peak":peak_draws,
			"visible_objects_peak":peak_objects}
		scores.append(record)
	var out: Dictionary = {"engine":Engine.get_version_info()["string"],
		"renderer":"Mesa llvmpipe Compatibility virtual X11",
		"actual_target_hardware_tested":false,
		"room_groups":total_groups,"logical_modules":scene.world.rooms.size(),
		"resident_banks_validated":scene.validated_visual_banks,
		"results":scores}
	var f := FileAccess.open("/home/user/dragon-house-fresh/qa_runtime_v03.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"\t"))
	f.close()
	print("RENDER_QA_V03: "+JSON.stringify(out))
	quit(0)

