extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.zoom_current=10.0

	var work={
		"phase":"perform","intent":"WORK_CREATE",
		"station_kind":"work","station_pose_hint":"USE"
	}
	assert(scene.desired_actor_animation(work)=="USE")

	var work_wrong_kind={
		"phase":"perform","intent":"WORK_CREATE",
		"station_kind":"standing","station_pose_hint":"USE"
	}
	assert(scene.desired_actor_animation(work_wrong_kind)=="IDLE_S")

	var talk={
		"phase":"perform","intent":"TALK_PAIR",
		"station_kind":"seat","station_pose_hint":"TALK"
	}
	assert(scene.desired_actor_animation(talk)=="TALK")

	var floor_sleep={
		"phase":"perform","intent":"REST",
		"station_kind":"floor_rest","station_pose_hint":"SLEEP"
	}
	assert(scene.desired_actor_animation(floor_sleep)=="SLEEP")

	print("AUTHORED_STATION_POSES_V016_PASS work=USE talk=TALK floor_rest=SLEEP unsafe_work=IDLE_S")
	quit(0)
