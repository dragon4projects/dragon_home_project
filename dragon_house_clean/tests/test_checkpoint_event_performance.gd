extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func stats(a:Array)->Dictionary:
 a.sort()
 return {"count":a.size(),"p50_us":a[int((a.size()-1)*0.5)],"p95_us":a[int((a.size()-1)*0.95)],"max_us":a[-1]}
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path="user://dragon_house_canonical_architecture_20261125.json"
 assert(w.load_or_seed())
 assert(w.runtime_state.object_event_backend.begins_with("sqlite"))
 var store=w.object_events.store
 var room:Dictionary=w.matching_rooms(["library"])[0]
 assert(w.register_physical_object("QA_PERF","QA perf","",room.id,true,true,false,false,false,{}))
 var initial:int=store.last_sequence()
 var append_us:Array=[]
 var save_us:Array=[]
 var original:Array=store.snapshot_events()
 for i in range(80):
  var start:int=Time.get_ticks_usec()
  assert(w.set_object_ambient_protection("QA_PERF",i%2==0))
  append_us.append(Time.get_ticks_usec()-start)
  assert(store.last_sequence()==initial+i+1)
  assert(store.has_event(str(store.events[-1].event_id)))
  assert(store.events[-1].payload.ambient_protected==(i%2==0))
  if i%8==0:
   start=Time.get_ticks_usec()
   assert(w.save_world())
   save_us.append(Time.get_ticks_usec()-start)
 assert(store.events.slice(0,initial)==original)
 var projection:Dictionary=store.derived_objects_snapshot()
 assert(projection==w.objects)
 var expected:Array=store.snapshot_events()
 var bytes:int=FileAccess.get_file_as_bytes(w.save_path).size()
 store.close()
 var restored=W.new()
 restored.canonical_house_seed=true
 restored.save_path=w.save_path
 assert(restored.load_or_seed())
 assert(restored.object_events.store.snapshot_events()==expected)
 assert(restored.objects==projection)
 print("CHECKPOINT_EVENT_PERF_PASS initial=",initial," appended=80 snapshot_bytes=",bytes," append=",stats(append_us)," save=",stats(save_us)," projection=true replay=true")
 quit(0)
