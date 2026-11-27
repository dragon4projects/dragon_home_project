extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func arrive(life,actor:Dictionary)->void:
 for i in range(3200):
  life.clock+=.125;life.world.sim_clock=life.clock
  life._move(actor,.125)
  if actor.get("phase")!="travel" or int(actor.get("waypoint_index",0))==0:break
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life;var m=life.media_runtime;var nav=life.candidate_navigation
 if not must(scene.complete_sprite_ready and scene.dense_services_qa,"I90 live scene"):return
 var prior:Dictionary={}
 if FileAccess.file_exists("user://i91_prior_book_assignments.json"):
  prior=JSON.parse_string(FileAccess.get_file_as_string("user://i91_prior_book_assignments.json"))
 var restart:bool=OS.get_environment("I91_BOOK_RESTART")=="1"
 var all_slots:=0
 var occupied:Dictionary={}
 var counts:Dictionary={}
 var measured:Array=[]
 for room in w.matching_rooms(["library"]):
  if not scene.dense_v2.has_room(room.id):continue
  var slots:Array=nav.book_slots(room)
  var key:String=scene.dense_v2.by_room[room.id].compiled.key
  var expected:int=60 if key=="L2_library" else 65
  if not must(slots.size()==expected,"book capacity "+key+" actual "+str(slots.size())):return
  all_slots+=slots.size();counts[room.id]=0;measured.append(room)
  var stations:Array=nav.candidate_spots(room)
  for slot in slots:
   var matched:Array=stations.filter(func(x):return x.id==slot.station_id)
   if not must(matched.size()==1 and not nav.path(room,Vector2(-7.12,1.5),matched[0].offset).is_empty() and not nav.path(room,Vector2(7.12,1.5),matched[0].offset).is_empty(),"shelf route missing"):return
 var total:=0
 for b in w.media.books:
  if not str(b.id).begins_with("BOOK_"):continue
  var slot:Dictionary=m.book_slot(b.id)
  if not must(b.physical and not slot.is_empty(),"catalog volume unplaced "+str(b.id)):return
  var key:String=slot.room_id+"|"+slot.id
  if not must(not occupied.has(key),"overlapping support identity"):return
  occupied[key]=b.id;counts[slot.room_id]+=1;total+=1
  if prior.has(b.id) and not must(prior[b.id].room_id==slot.room_id and prior[b.id].slot_id==slot.id,"prior support changed "+str(b.id)):return
 if not must(total==76 and all_slots==125 and counts.values().min()==38 and counts.values().max()==38,"catalog placement "+str([total,all_slots,counts])):return
 var imported:Dictionary=m._lookup("books","QA_I91_PLACED_BOOK")
 if not restart:
  var selected:Dictionary=measured[0]
  var free:Dictionary=m.free_book_slot("QA_I91_PLACED_BOOK",selected)
  if not must(not free.is_empty(),"no free qualified home"):return
  var manifest:Dictionary={"books":[{"id":"QA_I91_PLACED_BOOK","title":"QA physical import","reading_seconds":600,"home_room_id":selected.id,"home_slot_id":free.id}]}
  var f:=FileAccess.open("user://qa_i91_placed_book.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest));f.close()
  scene._import_media("user://qa_i91_placed_book.json")
  imported=m._lookup("books","QA_I91_PLACED_BOOK")
  if not must(imported.get("physical",false) and m.book_slot(imported.id).id==free.id,"explicit import slot"):return
  var actor:Dictionary=w.residents["RES_07"]
  life.stations.release(actor)
  var c:Vector3=w.room_center_pos(selected)
  actor["room_id"]=selected.id;actor["level"]=selected.level;actor["x"]=c.x;actor["z"]=1.5;actor["visual_y"]=c.y;actor["phase"]="idle"
  actor.erase("held_book");life._clear_book_task(actor)
  if not must(life._book_route(actor,selected,"FETCH_BOOK",free.station_id),"pickup route"):return
  actor["book_task_stage"]="fetch";actor["book_task_id"]=imported.id;actor["book_source_room"]=selected.id;actor["book_read_room"]=selected.id
  if not must(not m.borrow_at_shelf(actor.id,imported.id,selected.id),"pickup before arrival rejected"):return
  arrive(life,actor)
  if not must(actor.get("book_task_stage")=="read" and imported.holder_id==actor.id,"physical pickup/read seat"):return
  arrive(life,actor)
  if not must(actor.get("phase")=="perform" and actor.get("intent")=="READ_BOOK","arrived at reading station"):return
  life.clock+=40.0;w.sim_clock=life.clock
  if not must(life._continue_book_task(actor) and actor.get("book_task_stage")=="return","read/return route"):return
  arrive(life,actor)
  if not must(imported.holder_id=="" and not actor.has("held_book"),"return"):return
 if not must(imported.get("physical",false) and imported.get("holder_id","")=="" and not m.book_slot(imported.id).is_empty() and float(imported.get("progress_by_actor",{}).get("RES_07",0))>=40.0,"imported volume persistence"):return
 if not must(w.save_world(),"save"):return
 print("I91_MEASURED_BOOKS_PASS slots=",all_slots," canonical=",total," room_counts=",counts," old_preserved=",prior.size()," imported_cycle=true restart=",restart)
 quit(0)
