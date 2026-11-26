extends SceneTree
const W=preload("res://scripts/world_model.gd")
const R=preload("res://scripts/object_event_reducer.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")
 var w=W.new()
 w.save_path="user://qa_projection_reference.json"
 assert(w.load_or_seed())
 var room:Dictionary=w.get_room(1,-1)
 for id in ["QA_A","QA_B"]:
  assert(w.register_physical_object(id,id,"",room.id,true,true,false,false,false,{"interaction_point":[0.0,0.2]}))
 var a:Dictionary=w.objects.QA_A
 var b:Dictionary=w.objects.QA_B
 var b_history:Array=b.history
 var before:Dictionary=b.duplicate(true)
 assert(w.set_object_ambient_protection("QA_A",true))
 assert(is_same(a,w.objects.QA_A) and a.ambient_protected)
 assert(is_same(b,w.objects.QA_B) and is_same(b_history,b.history) and b==before)
 assert(w.object_events.store.derived_objects_snapshot()==w.objects)
 var r=R.new()
 var events:Array=w.object_events.store.snapshot_events()
 var copy:Array=events.duplicate(true)
 var replayed:Dictionary=r.replay(events)
 replayed.QA_A.interaction_point.append(99)
 assert(events==copy)
 assert(w.objects.QA_A.interaction_point==[0.0,0.2])
 print("OBJECT_PROJECTION_REFERENCE_PASS changed_identity=true unchanged_history_identity=true detached_event_metadata=true")
 quit(0)
