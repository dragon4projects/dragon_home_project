extends SceneTree
const R=preload("res://scripts/object_event_reducer.gd")
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path="user://dragon_house_canonical_architecture_20261125.json"
 assert(w.load_or_seed())
 var events:Array=w.object_events.store.snapshot_events()
 assert(events.size()>=700)
 var expected:Dictionary=w.objects.duplicate(true)
 var r=R.new()
 var times:Array=[]
 for i in range(5):
  var start:=Time.get_ticks_usec()
  var result:Dictionary=r.replay(events)
  times.append(Time.get_ticks_usec()-start)
  assert(result==expected)
  result.clear()
 # Public reduce must still be a detached, non-mutating operation.
 var initial:Dictionary=r.replay(events.slice(0,events.size()-1))
 var before:Dictionary=initial.duplicate(true)
 var last:Dictionary=r.reduce(initial,events[-1])
 assert(last==expected and initial==before)
 var id:String=str(last.keys()[0])
 last[id]["history"].append({"qa":"detached"})
 assert(initial==before)
 # Replay must not alias nested input metadata or corrupt earlier results.
 var original:Array=events.duplicate(true)
 var output:Dictionary=r.replay(events)
 for item in output.values():
  if item.get("interaction_point",[]) is Array:item["interaction_point"].append(123)
  item["history"].clear()
 assert(events==original)
 var invalid:Array=events.duplicate(true)
 invalid.append({"event_type":"QA_INVALID","payload":{"object_id":id}})
 assert(r.replay(invalid).is_empty() and r.last_error!="")
 assert(r.replay(events)==expected)
 times.sort()
 print("OBJECT_REPLAY_SCALING_PASS events=",events.size()," objects=",expected.size()," replay_median_us=",times[2]," replay_max_us=",times[-1]," purity=true")
 quit(0)
