extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")
 var w=W.new()
 w.save_path="user://qa_projection_delta.json"
 assert(w.load_or_seed())
 var room:Dictionary=w.get_room(1,-1)
 for id in ["QA_A","QA_B","QA_C"]:
  assert(w.register_physical_object(id,id,"",room.id,true,true,false,false,false,{}))
 var s=w.object_events.store
 assert(s._projection_known and s.last_projection_writes==1)
 assert(s.derived_objects_snapshot()==w.objects)
 # Reject ANY rewrite of an unrelated row. The change must still succeed.
 assert(s._query("CREATE TRIGGER preserve_b BEFORE INSERT ON objects WHEN NEW.object_id='QA_B' BEGIN SELECT RAISE(ABORT,'unrelated insert'); END;"))
 assert(s._query("CREATE TRIGGER preserve_b_delete BEFORE DELETE ON objects WHEN OLD.object_id='QA_B' BEGIN SELECT RAISE(ABORT,'unrelated delete'); END;"))
 assert(w.set_object_ambient_protection("QA_A",true))
 assert(s.last_projection_writes==1 and s.last_projection_deletes==0)
 assert(s.derived_objects_snapshot()==w.objects)
 var before:Dictionary=w.objects.duplicate(true)
 var events:Array=s.snapshot_events()
 var revision:int=s.last_sequence()
 # A derived row write failure rolls back the new canonical event too.
 assert(s._query("CREATE TRIGGER fail_a BEFORE INSERT ON objects WHEN NEW.object_id='QA_A' BEGIN SELECT RAISE(ABORT,'injected projection failure'); END;"))
 assert(not w.set_object_ambient_protection("QA_A",false))
 assert(s.last_sequence()==revision and s.snapshot_events()==events)
 assert(w.objects==before and s._projection_cache==before)
 assert(s.derived_objects_snapshot()==before)
 assert(s._query("SELECT COUNT(*) AS n FROM events;"))
 assert(int(s._rows()[0].n)==revision)
 assert(s._query("DROP TRIGGER fail_a;"))
 assert(s._query("DROP TRIGGER preserve_b;"))
 assert(s._query("DROP TRIGGER preserve_b_delete;"))
 assert(w.save_world())
 s.close()
 var r=W.new()
 r.save_path=w.save_path
 assert(r.load_or_seed())
 s=r.object_events.store
 assert(r.objects==before and s.snapshot_events()==events)
 assert(s._projection_known and s.derived_objects_snapshot()==before)
 assert(r.set_object_ambient_protection("QA_C",true))
 assert(s.last_projection_writes==1 and s.last_sequence()==revision+1)
 assert(s.derived_objects_snapshot()==r.objects)
 print("SQLITE_PROJECTION_DELTA_PASS untouched_row=true rollback=true canonical_order=true restart=true")
 quit(0)
