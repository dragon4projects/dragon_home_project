extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var sync:Array=[];var capture:Array=[];var worker:Array=[]
 for i in range(4):
  w.sim_clock+=20.0
  var t:=Time.get_ticks_usec()
  assert(w.save_world())
  sync.append(Time.get_ticks_usec()-t)
 w.async_checkpoint_enabled=true
 for i in range(4):
  w.sim_clock+=20.0
  var t:=Time.get_ticks_usec()
  assert(w.checkpoint_if_due())
  capture.append(Time.get_ticks_usec()-t)
  assert(w.poll_checkpoint(true))
  worker.append(w.checkpoint_worker_usec)
 assert(w.last_checkpoint_clock==w.sim_clock)
 var nav=scene.life.candidate_navigation
 var checks:=0
 for room in w.rooms:
  if not nav.has_layout(room):continue
  var points:Array=nav.candidate_spots(room)
  var standing:Array=points.filter(func(p):return p.kind=="standing" and p.furniture_id=="")
  for i in range(standing.size()):
   for j in range(i):
    var a:Vector2=standing[i].offset;var b:Vector2=standing[j].offset
    var expected:bool=nav.segment_clear(room,a,b)
    assert(nav.social_segment_clear(room,a,b)==expected)
    assert(nav.social_segment_clear(room,b,a)==expected)
    checks+=1
 assert(checks>0 and nav.social_segment_hits>=checks)
 print("DEPTH7_INTERACTIVE_CHECKPOINT_PASS sync_us=",sync," capture_us=",capture," worker_us=",worker," social_pairs=",checks," cache_hits=",nav.social_segment_hits)
 quit()
