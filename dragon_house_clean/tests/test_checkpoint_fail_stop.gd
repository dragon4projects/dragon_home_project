extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")
func _initialize()->void:
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var w=W.new()
	w.save_path="user://checkpoint_fail_stop.json"
	assert(w.load_or_seed())
	assert(w.last_checkpoint_clock==0.0)
	w.sim_clock=19.875
	assert(w.checkpoint_if_due())
	assert(w.last_checkpoint_clock==0.0)
	w.sim_clock=20.0
	assert(w.checkpoint_if_due())
	assert(w.last_checkpoint_clock==20.0)
	var primary:String=FileAccess.get_sha256(w.save_path)
	var backup:String=FileAccess.get_sha256(w.save_path+".bak")
	assert(primary!="" and backup!="")
	# A directory at the scratch path deterministically prevents writes,
	# even when the test runs with elevated filesystem privileges.
	assert(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(w.save_path+".tmp"))==OK)
	w.sim_clock=40.0
	assert(not w.checkpoint_if_due())
	assert(w.recovery_blocked and w.load_status=="CHECKPOINT_WRITE_FAILED")
	assert(w.last_checkpoint_clock==20.0)
	var life=Life.new()
	life.world=w
	life.clock=w.sim_clock
	life.tick(10.0)
	assert(life.clock==40.0 and w.sim_clock==40.0)
	assert(not w.save_world())
	assert(not w._ensure_object_events())
	assert(primary==FileAccess.get_sha256(w.save_path))
	assert(backup==FileAccess.get_sha256(w.save_path+".bak"))
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+".tmp"))==OK)
	var resumed=W.new()
	resumed.save_path=w.save_path
	assert(resumed.load_or_seed())
	assert(resumed.sim_clock==20.0 and resumed.last_checkpoint_clock==20.0)
	assert(not resumed.recovery_blocked)
	resumed.sim_clock=40.0
	assert(resumed.checkpoint_if_due())
	assert(resumed.last_checkpoint_clock==40.0)
	print("CHECKPOINT_FAIL_STOP_PASS interval=20 exact_due=true write_denied=true clock_frozen=true primary_backup_unchanged=true recovered=20")
	quit(0)
