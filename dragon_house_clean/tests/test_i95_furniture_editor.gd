extends SceneTree
const F=preload("res://scripts/local_furniture_layout.gd")
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var ui=scene.local_house_controls
 if OS.get_environment("DRAGON_I95_FURNITURE_RESTART")=="1":
  var saved:Dictionary=w.runtime_state.get(F.KEY,{})
  if not must(not saved.is_empty(),"missing saved offset"):return
  var rid:String=saved.keys()[0]
  var id:String=saved[rid].keys()[0]
  var e:Dictionary=scene.dense_v2.by_room[rid]
  var current:Dictionary=F.find(e.compiled,id)
  var old:Dictionary=F.find(e.base_compiled,id)
  var delta:Array=saved[rid][id].delta
  if not must(F.vec(current.pivot).distance_to(F.vec(old.pivot)+Vector3(delta[0],0,delta[1]))<.0001,"restart geometry differs"):return
  print("I95_FURNITURE_RESTART_PASS ",rid," ",id)
  quit(0);return
 var rid:String=""
 var id:String=""
 var delta:=Vector2.ZERO
 for key in scene.dense_v2.by_room:
  var entry:Dictionary=scene.dense_v2.by_room[key]
  var compiled:Dictionary=entry.compiled
  for p in compiled.placements:
   if not F.allowed(compiled,p):continue
   for d in [Vector2(.10,0),Vector2(-.10,0),Vector2(.20,0),Vector2(-.20,0),Vector2(0,.10),Vector2(0,-.10),Vector2(.05,0),Vector2(-.05,0),Vector2(0,.05),Vector2(0,-.05),Vector2(.3,0),Vector2(-.3,0)]:
    var trial:Dictionary=F.proposal(compiled,p.id,d)
    if trial.is_empty():continue
    var nav=scene.life.candidate_navigation
    var room:Dictionary=w.room_by_id(key)
    var row:Dictionary=F.row_after(nav.layouts[entry.variant],trial,p.id)
    if F.safe_occupants(w,nav,room,row,p,F.find(trial,p.id)) and F.paths_preserved(nav,room,row):
     rid=key;id=p.id;delta=d;break
   if rid!="":break
  if rid!="":break
 if not must(rid!="","no safe idle-room editable fixture"):return
 var entry:Dictionary=scene.dense_v2.by_room[rid]
 var p:Dictionary=F.find(entry.compiled,id)
 var pivot:=F.vec(p.pivot)
 var topology:Array=w.rooms.duplicate(true)
 if not must(not F.commit(scene,rid,id,Vector2(100,0)),"out-of-bounds accepted"):return
 if not must(F.commit(scene,rid,id,delta),"safe move rejected"):return
 if not must(F.vec(F.find(entry.compiled,id).pivot).distance_to(pivot+Vector3(delta.x,0,delta.y))<.0001 and w.rooms==topology,"transform or topology mismatch"):return
 ui.open_furniture()
 await process_frame
 if not must(ui.first.item_count>0,"furniture UI not populated"):return
 ui.dialog.hide()
 print("I95_FURNITURE_EDITOR_PASS room=",rid," id=",id," delta=",delta," geometry=true persistence=true topology_unchanged=true")
 quit(0)
