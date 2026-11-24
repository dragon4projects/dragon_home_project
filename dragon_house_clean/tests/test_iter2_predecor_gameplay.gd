extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
const V=preload("res://scripts/content_viewer.gd")
const I=preload("res://scripts/runtime_object_import.gd")

func _initialize()->void:
	call_deferred("run")

func run()->void:
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var path:String="user://iter2_predecor_gameplay.json"
	for suffix in ["",".bak",".tmp",".world_events_v1.json",".world_events_v1.json.bak",".world_events_v1.json.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var w=W.new()
	w.save_path=path
	w.seed_world()
	var common:Dictionary=w.get_room(-2,0)
	var library:Dictionary=w.get_room(2,0)
	var art:Dictionary=w.get_room(1,-1)
	assert(w.register_physical_object("WALL_TEST","Wall test","",art["id"],false,false,false,false,true,{"display_mode":"wall","home_anchor":[-0.55,1.45,-1.52],"interaction_station_id":"WALL_TEST","interaction_point":[-0.55,-1.22]}))
	var item:Dictionary=w.physical_object("WALL_TEST")
	assert(absf(float(item["home_anchor"][1])+1.52)<0.001)
	assert(not w.assign_physical_object_home("WALL_TEST",common["id"],Vector2.ZERO,true))
	assert(w.assign_physical_object_home("WALL_TEST",common["id"],Vector2(0.75,-1.52),true))
	item=w.physical_object("WALL_TEST")
	assert(str(item["home_room_id"])==str(common["id"]))
	assert(absf(float(item["display_anchor"][0])-0.75)<0.001)
	assert(absf(float(item["display_anchor"][1])-1.45)<0.001)
	assert(absf(float(item["interaction_point"][0])-0.75)<0.001)
	assert(not w.can_ambient_pickup_object("WALL_TEST"))
	w.media["books"]=[{"id":"BOOK","title":"Book","physical":true},{"id":"REFERENCE","title":"Reference","physical":false}]
	w.media["films"]=[{"id":"FILM_OLD","title":"Film"}]
	var m=M.new()
	m.setup(w)
	assert(m.tick_book_home_reset()==0)
	assert(m.borrow("RES_01","BOOK",1))
	w.residents["RES_01"]["held_book"]="BOOK"
	var catalog:String="user://iter2_predecor_catalog.json"
	var file:=FileAccess.open(catalog,FileAccess.WRITE)
	file.store_string(JSON.stringify({"tracks":[{"id":"TRACK_NEW","title":"Track"}]}))
	file.close()
	assert(w.import_catalog(catalog))
	assert(w.media["films"].size()==1 and w.media["tracks"].size()==1)
	assert(w.media["books"].size()==2 and str(m._lookup("books","BOOK")["holder_id"])=="RES_01")
	w.sim_clock=W.GAME_DAY_SECONDS+1.0
	assert(m.tick_book_home_reset()==1)
	assert(str(m._lookup("books","BOOK")["location_room_id"])==str(library["id"]))
	assert(str(m._lookup("books","BOOK")["holder_id"])=="")
	assert(str(m._lookup("books","REFERENCE")["location_room_id"])=="")
	assert(str(w.residents["RES_01"].get("held_book",""))=="")
	assert(m.tick_book_home_reset()==0)
	assert(w.save_world())
	var reloaded=W.new()
	reloaded.save_path=path
	reloaded.load_or_seed()
	assert(absf(float(reloaded.physical_object("WALL_TEST")["display_anchor"][0])-0.75)<0.001)
	assert(str(reloaded.physical_object("WALL_TEST")["home_room_id"])==str(common["id"]))
	assert(reloaded.media["books"].size()==2)
	var viewer=V.new()
	root.add_child(viewer)
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var tex:=ImageTexture.create_from_image(image)
	assert(viewer.open_record("creatures",{"id":"CAT_TEST","display_name":"Cat · owner"},tex))
	assert(viewer.preview.texture==tex and viewer.title_label.text=="Cat · owner")
	viewer.queue_free()
	var image_path:String="user://iter2_import_test.png"
	assert(image.save_png(image_path)==OK)
	var object_catalog:String="user://iter2_import_objects.json"
	var object_file:=FileAccess.open(object_catalog,FileAccess.WRITE)
	object_file.store_string(JSON.stringify({"posters":[{"id":"IMPORT_POSTER","title":"Imported poster","home_room_id":art["id"],"home_anchor":[0.3,1.4,-1.52],"preview_path":image_path}],"cups":[{"id":"IMPORT_CUP","title":"Imported cup","home_room_id":common["id"],"home_anchor":[0.4,0.4],"preview_path":image_path}]}))
	object_file.close()
	var importer=I.new()
	var imported:Dictionary=importer.import_file(reloaded,object_catalog)
	assert(bool(imported.get("ok",false)) and int(imported.get("added",0))==2)
	assert(str(reloaded.physical_object("IMPORT_POSTER")["viewer_category"])=="posters")
	assert(not reloaded.can_ambient_pickup_object("IMPORT_CUP"))
	assert(not bool(importer.import_file(reloaded,object_catalog).get("ok",false)))
	for id in ["IMPORT_POSTER","IMPORT_CUP"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(reloaded.physical_object(id)["preview_path"])))
	for filename in [image_path,object_catalog]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	for suffix in ["",".bak",".tmp",".world_events_v1.json",".world_events_v1.json.bak",".world_events_v1.json.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog))
	print("ITER2_PREDECOR_GAMEPLAY_PASS wall_home=true book_daily=true additive_catalog=true creature_viewer=true")
	quit(0)
