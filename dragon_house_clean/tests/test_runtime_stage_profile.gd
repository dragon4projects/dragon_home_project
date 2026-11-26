extends SceneTree
## QA only: no instrumentation in production tick. Run in isolated XDG_DATA_HOME.
class ProfileLife extends "res://scripts/life.gd":
 var due_us:=0
 var move_us:=0
 var due_calls:=0
 var move_calls:=0
 func _process_due_actor(id:String,reason:String)->void:
  var start:=Time.get_ticks_usec()
  super._process_due_actor(id,reason)
  due_us+=Time.get_ticks_usec()-start
  due_calls+=1
 func _move(actor:Dictionary,delta:float)->void:
  var start:=Time.get_ticks_usec()
  super._move(actor,delta)
  move_us+=Time.get_ticks_usec()-start
  move_calls+=1
class Fixture extends "res://scripts/main.gd":
 func _ready()->void:
  life=ProfileLife.new()
  super._ready()
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func stats(a:Array)->Dictionary:
 if a.is_empty():return {}
 a.sort()
 return {"n":a.size(),"p50_us":a[int((a.size()-1)*0.5)],"p95_us":a[int((a.size()-1)*0.95)],"max_us":a[-1]}
func run()->void:
 var scene=Fixture.new()
 root.add_child(scene)
 current_scene=scene
 assert(scene.architecture_review and scene.teea008_live)
 var w=scene.world
 var l:ProfileLife=scene.life
 var ticks:Array=[]
 var events:Array=[]
 var no_events:Array=[]
 var due:Array=[]
 var moves:Array=[]
 var other:Array=[]
 var save:Array=[]
 var slow:Array=[]
 for i in range(960):
  l.due_us=0
  l.move_us=0
  l.due_calls=0
  l.move_calls=0
  var seq:int=w.object_event_revision()
  var before:float=w.last_checkpoint_clock
  var start:=Time.get_ticks_usec()
  l.tick(0.125)
  var elapsed:int=Time.get_ticks_usec()-start
  ticks.append(elapsed)
  if w.object_event_revision()!=seq:events.append(elapsed)
  else:no_events.append(elapsed)
  due.append(l.due_us)
  moves.append(l.move_us)
  other.append(maxi(0,elapsed-l.due_us-l.move_us))
  if elapsed>=25000:slow.append({"tick":i,"total_us":elapsed,"due_us":l.due_us,"move_us":l.move_us,"event_count":w.object_event_revision()-seq})
  start=Time.get_ticks_usec()
  assert(w.checkpoint_if_due())
  if w.last_checkpoint_clock!=before:save.append(Time.get_ticks_usec()-start)
 slow.sort_custom(func(a,b):return a.total_us>b.total_us)
 print("RUNTIME_STAGE_PROFILE_PASS ticks=",stats(ticks)," with_event=",stats(events)," without_event=",stats(no_events)," due=",stats(due)," move=",stats(moves)," remaining=",stats(other)," checkpoint=",stats(save)," top=",slow.slice(0,5))
 quit(0)
