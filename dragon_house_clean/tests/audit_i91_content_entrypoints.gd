extends SceneTree
func _initialize()->void:call_deferred("run")
func require(ok:bool,msg:String)->bool:
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
 var nav=scene.life.candidate_navigation
 var m=scene.life.media_runtime
 if not require(scene.complete_sprite_ready and scene.dense_services_qa,"actual I90 QA scene not ready"):return
 for rid in scene.dense_v2.by_room:
  var room:Dictionary=w.room_by_id(rid)
  var spots:Array=nav.candidate_spots(room)
  var seat_count:int=spots.filter(func(s):return s.get("kind","")=="seat").size()
  var book_slots:Array=nav.book_slots(room)
  var shelves:Array=book_slots.map(func(s):return s.get("furniture_id",""))
  print("I91_ROOM ",scene.dense_v2.by_room[rid].compiled.key," seat=",seat_count," book_slots=",book_slots.size()," shelf_ids=",shelves)
 var existing:int=0
 var assigned:int=0
 for b in w.media.books:
  if bool(b.get("physical",true)):existing+=1
  if not m.book_slot(b.id).is_empty():assigned+=1
 print("I91_CATALOG books=",w.media.books.size()," physical=",existing," slots_assigned=",assigned," films=",w.media.films.size()," tracks=",w.media.tracks.size())
 var test_id:String="I91_BASELINE_NEW"
 var image:=Image.create_empty(120,80,false,Image.FORMAT_RGBA8)
 image.fill(Color("#754abe"))
 assert(image.save_png("user://i91_preview.png")==OK)
 var data={"books":[{"id":test_id+"_BOOK","title":"QA test book","preview":"i91_preview.png"}],"films":[{"id":test_id+"_FILM","title":"QA test film","media_type":"film","simulation_only":true,"runtime_seconds":110,"preview":"i91_preview.png"}],"tracks":[{"id":test_id+"_TRACK","title":"QA test track","simulation_only":true,"autonomous_music":true,"runtime_seconds":40,"preview":"i91_preview.png"}]}
 var f:=FileAccess.open("user://i91_input.json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
 scene._import_media("user://i91_input.json")
 for c in ["books","films","tracks"]:
  var id:String=test_id+("_BOOK" if c=="books" else "_FILM" if c=="films" else "_TRACK")
  var b:Dictionary=m._lookup(c,id)
  print("I91_BASELINE_IMPORT ",c," registered=",not b.is_empty()," viewer=",scene.content_viewer.open_record(c,b)," preview=",scene.content_viewer.preview.texture!=null," book_slot=",not m.book_slot(id).is_empty())
 print("I91_BASELINE_AUDIT_COMPLETE")
 quit(0)
