extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var w=W.new()
 w.save_path="user://snapshot_digest_rotation.json"
 assert(w.load_or_seed())
 var before:int=w._snapshot_full_validation_count
 w.sim_clock=20.0
 assert(w.save_world())
 assert(w._snapshot_digest_hits==1 and w._snapshot_full_validation_count==before+1)
 var backup:String=FileAccess.get_sha256(w.save_path+".bak")
 # An externally damaged primary must not replace the last valid backup.
 var f:=FileAccess.open(w.save_path,FileAccess.WRITE)
 f.store_string("{broken")
 f.close()
 before=w._snapshot_full_validation_count
 w.sim_clock=40.0
 assert(w.save_world())
 assert(w._snapshot_full_validation_count==before+2)
 assert(w._snapshot_digest_hits==1 and FileAccess.get_sha256(w.save_path+".bak")==backup)
 # A different but valid primary must be validated rather than trusted or
 # discarded, and must become the new backup.
 var changed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path))
 changed["sim_clock"]=42.0
 f=FileAccess.open(w.save_path,FileAccess.WRITE)
 f.store_string(JSON.stringify(changed))
 f.close()
 var changed_hash:String=FileAccess.get_sha256(w.save_path)
 before=w._snapshot_full_validation_count
 w.sim_clock=60.0
 assert(w.save_world())
 assert(w._snapshot_full_validation_count==before+2)
 assert(FileAccess.get_sha256(w.save_path+".bak")==changed_hash)
 var fresh=W.new()
 fresh.save_path=w.save_path
 assert(fresh.load_or_seed() and fresh.sim_clock==60.0)
 fresh.sim_clock=80.0
 assert(fresh.save_world() and fresh._snapshot_digest_hits==1)
 print("SNAPSHOT_DIGEST_ROTATION_PASS verified_cache=true corrupt_primary_backup_preserved=true changed_valid_primary_revalidated=true reload=true")
 quit(0)
