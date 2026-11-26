extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var w=W.new();w.canonical_house_seed=true;w.save_path="user://qa_async.json"
 assert(w.load_or_seed())
 w.async_checkpoint_enabled=true
 w.sim_clock=20.0
 w.residents.RES_01["qa_marker"]="captured"
 assert(w.checkpoint_if_due() and w._checkpoint_thread!=null)
 assert(w.last_checkpoint_clock==0.0)
 w.residents.RES_01["qa_marker"]="live_after_capture";w.sim_clock=21.0
 assert(w.poll_checkpoint(true))
 assert(w.last_checkpoint_clock==20.0)
 var captured:Dictionary=w._read_snapshot(w.save_path)
 assert(captured.residents.RES_01.qa_marker=="captured" and captured.sim_clock==20.0)
 assert(w.residents.RES_01.qa_marker=="live_after_capture")
 w.sim_clock=40.0
 assert(w.checkpoint_if_due())
 w.sim_clock=41.0
 assert(w.save_world() and w._checkpoint_thread==null)
 assert(w.last_checkpoint_clock==41.0)
 var again=W.new();again.canonical_house_seed=true;again.save_path=w.save_path;assert(again.load_or_seed())
 assert(again.sim_clock==41.0 and again.residents.RES_01.qa_marker=="live_after_capture")
 var before:String=FileAccess.get_sha256(w.save_path)
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(w.save_path+".tmp"))
 w.sim_clock=61.0
 assert(w.checkpoint_if_due())
 assert(not w.poll_checkpoint(true) and w.recovery_blocked)
 assert(w.last_checkpoint_clock==41.0 and FileAccess.get_sha256(w.save_path)==before)
 print("ASYNC_CHECKPOINT_PASS immutable_capture=true sync_drains=true failure_preserves_primary=true capture_us=",w.checkpoint_capture_usec)
 quit()
