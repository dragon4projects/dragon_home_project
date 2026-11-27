extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
const I=preload("res://scripts/local_media_catalog_import.gd")
const V=preload("res://scripts/content_viewer.gd")
func _initialize()->void:call_deferred("run")
func must(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(2)
 return ok
func write_json(d:Dictionary)->void:
 var f:=FileAccess.open("user://qa_i91_catalog.json",FileAccess.WRITE);f.store_string(JSON.stringify(d));f.close()
func run()->void:
 var w=W.new()
 w.save_path="user://qa_i91_import_world.json"
 if not must(w.load_or_seed(),"seed"):return
 var m=M.new();m.setup(w)
 var importer=I.new()
 var viewer=V.new();root.add_child(viewer);viewer.bind(m)
 var reload:bool=OS.get_environment("I91_RESTART")=="1"
 var original:="user://qa_i91_master.jpg"
 if not reload:
  var image:=Image.create_empty(1000,600,false,Image.FORMAT_RGB8);image.fill(Color("#7a5b93"))
  if not must(image.save_jpg(original,.9)==OK,"source jpeg"):return
  var f:=FileAccess.open("user://qa_i91_text.md",FileAccess.WRITE);f.store_string("I91 TEST TEXT");f.close()
  var d:Dictionary={"books":[{"id":"QA_I91_B","title":"QA book","author":"Fixture","preview":"qa_i91_master.jpg","content_path":"qa_i91_text.md","holder_id":"RES_01","physical":true}],"films":[{"id":"QA_I91_F","title":"QA film","runtime_seconds":130,"preview":"qa_i91_master.jpg"},{"id":"QA_I91_S","title":"QA series","media_type":"series","latest_season":1,"latest_episode":2,"episode_runtime_seconds":{"1":[100,120]},"complete_seasons":[1]}],"audio":[{"id":"QA_I91_T","title":"QA track","runtime_seconds":45,"preview":"qa_i91_master.jpg"}]}
  write_json(d)
  var r:Dictionary=importer.import_file(w,m,"user://qa_i91_catalog.json")
  if not must(r.ok and r.added==4 and r.placed_books==0,"import: "+str(r)):return
  var again:Dictionary=importer.import_file(w,m,"user://qa_i91_catalog.json")
  if not must(again.ok and again.added==0 and again.duplicates==4,"idempotent "+str(again)):return
  var before:Dictionary=w.media.duplicate(true)
  d.films[0].runtime_seconds=131
  write_json(d)
  if not must(not importer.import_file(w,m,"user://qa_i91_catalog.json").ok and w.media==before,"identity conflict"):return
  write_json({"films":[{"id":"QA_FAIL_PRE","title":"never added","runtime_seconds":20},{"id":"QA_FAIL","title":"bad","runtime_seconds":20,"preview":"../not-a-sibling.png"}]})
  if not must(not importer.import_file(w,m,"user://qa_i91_catalog.json").ok and w.media==before,"whole manifest preflight rejection"):return
  write_json({"books":[{"id":"QA_FAIL_SLOT","title":"bad slot","home_room_id":"BAD","home_slot_id":"BAD"}]})
  if not must(not importer.import_file(w,m,"user://qa_i91_catalog.json").ok and w.media==before,"unqualified physical slot"):return
  DirAccess.remove_absolute(ProjectSettings.globalize_path(original))
  DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_i91_text.md"))
 var b:Dictionary=m._lookup("books","QA_I91_B")
 var film:Dictionary=m._lookup("films","QA_I91_F")
 var series:Dictionary=m._lookup("films","QA_I91_S")
 var track:Dictionary=m._lookup("tracks","QA_I91_T")
 if not must(not b.is_empty() and not b.physical and b.holder_id=="" and not m.available_books().any(func(x):return x.id==b.id),"catalog not phantom physical"):return
 for record in [b,film,track]:
  if not must(I.verified_import_preview(record),"stored exact master/thumbnail"):return
  if not must(Image.load_from_file(record.preview).get_size()==Vector2i(512,307),"thumbnail dimensions"):return
  if not must(Image.load_from_file(record.full_image_path).get_size()==Vector2i(1000,600),"master dimensions"):return
 if not must(viewer.open_record("books",b) and viewer.preview.texture!=null and viewer.preview.texture.get_size()==Vector2(1000,600) and viewer.text_view.text=="I91 TEST TEXT","book master/text viewer"):return
 if not must(viewer.open_record("films",film) and viewer.preview.texture.get_size()==Vector2(1000,600) and m.next_watch_unit("RES_01",film).seconds==130,"film master and duration"):return
 if not must(m.next_watch_unit("RES_01",series).seconds==100,"series first episode"):return
 if not must(viewer.open_record("tracks",track) and viewer.preview.texture.get_size()==Vector2(1000,600) and m.track_duration(track)==45,"audio master/duration"):return
 print("I91_LOCAL_MEDIA_IMPORT_PASS restart=",reload," classes=3 records=4 masters=3 full_view=true duplicate_noop=true")
 quit(0)
