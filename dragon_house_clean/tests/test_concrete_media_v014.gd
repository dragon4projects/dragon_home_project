extends SceneTree
const World=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

func _initialize()->void:
	call_deferred("run")

func _fixture(path:String)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_8(0)
	f.close()

func _perform(actor:Dictionary)->void:
	actor["phase"]="perform"
	actor["waypoint_index"]=actor.get("waypoints",[]).size()

func run()->void:
	var video_path:="user://v014_fixture.ogv"
	var audio_path:="user://v014_fixture.wav"
	_fixture(video_path)
	_fixture(audio_path)

	var world=World.new()
	world.save_path="user://v014_concrete_media.json"
	world.seed_world()
	world.media={
		"books":[{
			"id":"BOOK_REAL_01","title":"Книга из тестовой полки",
			"physical":true,"holder_id":"",
			"location_room_id":world.get_room(2,0)["id"],
			"progress_by_actor":{}
		}],
		"films":[{
			"id":"FILM_PLAYABLE_01","title":"Проверяемый фильм",
			"file_path":video_path,"simulation_only":true,"media_type":"film","runtime_seconds":6000
		}],
		"tracks":[{
			"id":"TRACK_PLAYABLE_01","title":"Проверяемая запись",
			"file_path":audio_path,"simulation_only":true,"autonomous_music":true,"runtime_seconds":195
		}]
	}
	var life=Life.new()
	life.setup(world)

	var watcher:Dictionary=world.residents["RES_01"]
	life._assign(watcher,{"intent":"WATCH_FILM","room":world.get_room(4,0)})
	assert(str(watcher.get("activity_media_category",""))=="films")
	assert(str(watcher.get("activity_media_id",""))=="FILM_PLAYABLE_01")
	assert(str(watcher.get("activity_media_title",""))=="Проверяемый фильм")
	assert(life.status(watcher)=="идёт смотреть фильм")
	_perform(watcher)
	watcher["room_id"]=world.get_room(4,0)["id"]
	assert(life.media_runtime.begin_watch(watcher,life.clock))
	assert(life.status(watcher)=="смотрит «Проверяемый фильм»")

	var listener:Dictionary=world.residents["RES_02"]
	life._assign(listener,{"intent":"LISTEN_MUSIC","room":world.get_room(3,0)})
	assert(str(listener.get("activity_media_category",""))=="tracks")
	assert(str(listener.get("activity_media_id",""))=="TRACK_PLAYABLE_01")
	_perform(listener)
	listener["room_id"]=world.get_room(3,0)["id"]
	assert(life.media_runtime.begin_listen(listener,life.clock))
	assert(life.status(listener)=="слушает «Проверяемая запись»")

	var reader:Dictionary=world.residents["RES_03"]
	life._assign(reader,{"intent":"READ_BOOK","room":world.get_room(2,0)})
	assert(str(reader.get("held_book",""))=="BOOK_REAL_01")
	assert(str(reader.get("activity_media_category",""))=="books")
	assert(str(reader.get("activity_media_id",""))=="BOOK_REAL_01")
	_perform(reader)
	assert(life.status(reader)=="читает «Книга из тестовой полки»")
	assert(str(world.media["books"][0]["holder_id"])=="RES_03")
	# v0.13 save migration: a real held book can safely restore its identity
	# from holder_id; no title/ID is invented.
	life.end_concrete_media(reader)
	assert(not reader.has("activity_media_id"))
	assert(life.reconcile_concrete_media()==1)
	assert(str(reader.get("activity_media_id",""))=="BOOK_REAL_01")

	# Browsing stays browsing: it may name a catalogue entry, but it does not
	# create consumption state.
	var browser:Dictionary=world.residents["RES_04"]
	life._assign(browser,{"intent":"BROWSE_FILMS","room":world.get_room(4,0)})
	assert(str(browser.get("browsing_item_id",""))=="FILM_PLAYABLE_01")
	assert(not browser.has("activity_media_id"))
	_perform(browser)
	assert(life.status(browser)=="выбирает фильм «Проверяемый фильм»")

	# Starting another activity clears concrete media evidence. This does not
	# issue a stop/play command to the UI media players.
	life._assign(watcher,{"intent":"REST","room":world.get_room(1,0)})
	assert(not watcher.has("activity_media_id"))
	assert(not watcher.has("activity_media_category"))

	# Save/load truth: a simulated film is independent of video bytes but
	# loses eligibility if its duration metadata is removed.
	life._assign(watcher,{"intent":"WATCH_FILM","room":world.get_room(4,0)})
	_perform(watcher)
	assert(str(watcher.get("activity_media_id",""))=="FILM_PLAYABLE_01")
	watcher["room_id"]=world.get_room(4,0)["id"]
	assert(life.media_runtime.begin_watch(watcher,life.clock))
	world.media["films"][0].erase("runtime_seconds")
	assert(world.save_world())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(video_path))
	var recovered=World.new()
	recovered.save_path=world.save_path
	recovered.load_or_seed()
	var recovered_life=Life.new()
	recovered_life.setup(recovered)
	var recovered_watcher:Dictionary=recovered.residents["RES_01"]
	assert(not recovered_watcher.has("activity_media_id"))
	assert(str(recovered_watcher.get("phase",""))=="idle")
	assert(str(recovered_watcher.get("station_room_id",""))=="")

	# A catalogue record without known duration cannot become a timed watch.
	var no_file:Dictionary=world.residents["RES_05"]
	life._assign(no_file,{"intent":"WATCH_FILM","room":world.get_room(4,0)})
	assert(not no_file.has("activity_media_id"))

	for p in [audio_path,world.save_path]:
		for suffix in ["",".bak",".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p+suffix))
	print("CONCRETE_MEDIA_V014_PASS film=id_bound track=id_bound book=physical browse=catalog_only reload_missing_duration=cancelled")
	quit(0)
