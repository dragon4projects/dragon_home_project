extends SceneTree
func _initialize()->void:call_deferred("run")
func require(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(2)
 return ok
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var life=scene.life
 var ui=scene.local_house_controls
 var editor=ui.editor
 if not require(w.dense_artifact_world!=null,"grid adapter missing"):return
 ui.open_doors()
 await process_frame
 if not require(ui.first.item_count==24 and ui.second.item_count>0,"door selectors missing"):return
 var rid:String=ui.first.get_item_metadata(0)
 var room:Dictionary=w.room_by_id(rid)
 var before:Dictionary=w.PrivateDoorAccess.state(w,room).duplicate(true)
 ui.action.select(3)
 ui._apply()
 if not require(w.PrivateDoorAccess.state(w,room)==before,"unconfirmed command changed door"):return
 ui.confirm.button_pressed=true
 ui._apply()
 if not require(w.PrivateDoorAccess.state(w,room).get("open",false)==true and not w.public_cutaway_allowed(room),"explicit door open or privacy failed"):return
 ui.action.select(4);ui.confirm.button_pressed=true;ui._apply()
 if not require(not w.PrivateDoorAccess.state(w,room).get("open",true),"close failed"):return
 ui.dialog.hide()
 var artifact:String=""
 var opt:Dictionary={}
 for obj in w.objects.values():
  var opts:Array=editor.artifact_options(str(obj.id))
  if not opts.is_empty() and str(obj.get("home_support_id","")).begins_with("DG:"):
   artifact=obj.id;opt=opts[0];break
 if not require(artifact!="","no movable grid artifact"):return
 if not require(not editor.move_artifact(artifact,rid,opt.slot_id),"private destination accepted"):return
 if not require(editor.move_artifact(artifact,opt.room_id,opt.slot_id),"grid editor move rejected"):return
 if not require(w.physical_object(artifact).home_support_id==opt.slot_id and w.dense_artifact_world.validate_projection(w.objects),"grid projection mismatch"):return
 var book:String=""
 var dest:Dictionary={}
 for item in w.media.books:
  var opts:Array=editor.book_options(str(item.id))
  for row in opts:
   if row.room_id!=str(item.get("home_room_id","")):
    book=item.id;dest=row;break
  if book!="":break
 if not require(book!="","no free cross-library book support"):return
 var previous:Dictionary=life.media_runtime._lookup("books",book).duplicate(true)
 if not require(editor.move_book(book,dest.room_id,dest.slot_id),"book rehome failed"):return
 var moved:Dictionary=life.media_runtime._lookup("books",book)
 if not require(moved.home_room_id==dest.room_id and moved.home_slot_id==dest.slot_id and moved.get("progress_by_actor",{})==previous.get("progress_by_actor",{}),"book identity/progress changed"):return
 ui.open_editor();await process_frame
 if not require(ui.first.item_count>0,"editor UI empty"):return
 ui.dialog.hide()
 if not require(w.save_world(),"save failed"):return
 var W=load("res://scripts/world_model.gd")
 var again=W.new();again.canonical_house_seed=true;again.save_path=w.save_path
 again.dense_artifact_world=w.dense_artifact_world
 if not require(again.load_or_seed(),"restart failed"):return
 if not require(again.physical_object(artifact).home_support_id==opt.slot_id and again.runtime_state.teea008_book_slot_assignments[book]=={"room_id":dest.room_id,"slot_id":dest.slot_id},"editor changes lost on reload"):return
 print("I95_LOCAL_CONTROLS_PASS explicit_confirmation=true closed_privacy=true artifact_rehome=true book_rehome=true history_preserved=true restart=true")
 quit(0)
