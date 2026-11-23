extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.zoom_current=10.0

	var floor_sleep={
		"phase":"perform","intent":"SLEEP",
		"station_kind":"floor_rest","station_pose_hint":"SLEEP"
	}
	assert(scene.desired_actor_animation(floor_sleep)=="SLEEP")

	var floor_rest={
		"phase":"perform","intent":"REST",
		"station_kind":"floor_rest","station_pose_hint":"SLEEP"
	}
	assert(scene.desired_actor_animation(floor_rest)=="SLEEP")

	var seat_rest={
		"phase":"perform","intent":"REST",
		"station_kind":"seat","station_pose_hint":"RELAXED_SIT"
	}
	assert(scene.desired_actor_animation(seat_rest)=="RELAXED_SIT")

	var unsafe_standing={
		"phase":"perform","intent":"SLEEP",
		"station_kind":"standing","station_pose_hint":"SLEEP"
	}
	assert(scene.desired_actor_animation(unsafe_standing)=="IDLE_S")

	print("FLOOR_REST_POSE_V016_PASS sleep=floor_rest rest=authored_pose standing=no_fake_sleep")
	quit(0)
