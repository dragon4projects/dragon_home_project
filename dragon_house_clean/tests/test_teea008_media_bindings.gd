extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const M=preload("res://scripts/media_runtime.gd")
const R=preload("res://scripts/teea008_media_bindings.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var w=W.new()
	w.save_path="user://teea008_media_bindings_qa.json"
	w.seed_world()
	var a:Dictionary=w.get_room(4,0)
	var b:Dictionary=w.make_room(7,0,"cinema",1,false)
	var f:=FileAccess.open("user://qa_media.ogv",FileAccess.WRITE)
	f.store_8(0);f.close()
	var preview:=Image.create(64,64,false,Image.FORMAT_RGB8)
	preview.fill(Color("#6d253b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://filmix_previews"))
	assert(preview.save_webp("user://filmix_previews/QA.webp")==OK)
	w.media["films"]=[{"id":"QA_A","title":"QA A","simulation_only":true,"media_type":"film","runtime_seconds":3600,"preview":"user://filmix_previews/QA.webp"},{"id":"QA_B","title":"QA B","simulation_only":true,"media_type":"film","runtime_seconds":2400,"preview":"user://filmix_previews/QA.webp"},{"id":"QA_META","title":"metadata only"}]
	var bank=B.new()
	assert(bank.initialize(),bank.error)
	var media=M.new()
	media.setup(w)
	var binding=R.new()
	binding.setup(w,bank,media)
	var id: String="cinema.r1.film.screen"
	assert(binding.assign(a["id"],id,"films","QA_A"))
	assert(binding.assign(b["id"],id,"films","QA_B"))
	assert(binding.resolve(a["id"],id)["id"]=="QA_A")
	assert(binding.resolve(b["id"],id)["id"]=="QA_B")
	assert(not binding.assign(a["id"],id,"tracks","QA_A"))
	assert(not binding.assign(a["id"],id,"films","QA_META"))
	assert(not binding.assign(a["id"],"cinema.r2.film.screen","films","QA_A"))
	var actor:Dictionary=w.residents["RES_01"]
	actor["intent"]="WATCH_FILM"
	actor["station_room_id"]=a["id"]
	actor["phase"]="perform"
	actor["activity_media_id"]="QA_B"
	actor["room_id"]=a["id"]
	assert(media.begin_watch(actor,0))
	assert(binding.resolve(a["id"],id)["id"]=="QA_B")
	assert(binding.choose_film(a["id"],"RES_02")["id"]=="QA_B")
	actor["phase"]="idle"
	assert(binding.resolve(a["id"],id)["id"]=="QA_A")
	# Audio room selection follows an actual listener, then the saved pin.
	var music_room:Dictionary=w.get_room(3,0)
	if str(music_room.get("type",""))!="music":
		music_room=w.make_room(8,0,"music",1,false)
	var sound:=FileAccess.open("user://qa_track.ogg",FileAccess.WRITE)
	sound.store_8(0);sound.close()
	w.media["tracks"]=[{"id":"QA_TRACK_A","title":"A","file_path":"user://qa_track.ogg"},{"id":"QA_TRACK_B","title":"B","file_path":"user://qa_track.ogg"}]
	var music_id:String="music.r1.audio.01"
	assert(binding.assign(music_room["id"],music_id,"tracks","QA_TRACK_A"))
	assert(binding.resolve(music_room["id"],music_id)["id"]=="QA_TRACK_A")
	actor["intent"]="LISTEN_MUSIC"
	actor["station_room_id"]=music_room["id"]
	actor["room_id"]=music_room["id"]
	actor["phase"]="perform"
	actor["activity_media_id"]="QA_TRACK_B"
	assert(binding.resolve(music_room["id"],music_id)["id"]=="QA_TRACK_B")
	assert(binding.choose_track(music_room["id"],"RES_02")["id"]=="QA_TRACK_B")
	actor["phase"]="idle"
	assert(binding.resolve(music_room["id"],music_id)["id"]=="QA_TRACK_A")
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	media.setup(copy)
	binding.setup(copy,bank,media)
	assert(binding.resolve(a["id"],id)["id"]=="QA_A")
	assert(binding.resolve(b["id"],id)["id"]=="QA_B")
	assert(binding.assign(a["id"],id,"films",""))
	assert(binding.resolve(a["id"],id).is_empty())
	assert(binding.resolve(b["id"],id)["id"]=="QA_B")
	# ZNA preview records must be additive and never masquerade as playable.
	var original_films:int=copy.media["films"].size()
	var original_tracks:int=copy.media["tracks"].size()
	assert(copy.merge_zna_media_previews()==203)
	assert(copy.media["tracks"].size()==original_tracks+203)
	assert(copy.media["films"].size()==original_films)
	assert(media._lookup("films","YT_dpUIOPQgJpQ").is_empty())
	var source:Dictionary=media._lookup("tracks","YT_KJ6ogPmYjLI")
	assert(not source.is_empty() and str(source["preview"]).begins_with("res://assets/media/previews/audio/"))
	assert(ResourceLoader.exists(str(source["preview"]),"Texture2D"))
	assert(not media.playable("tracks").any(func(item):return item["id"]==source["id"]))
	assert(copy.merge_zna_media_previews()==0)
	assert(media._lookup("tracks","QA_TRACK_A")["file_path"]=="user://qa_track.ogg")
	print("TEEA008_MEDIA_BINDINGS_PASS zna_audio=203 private_cinema_separate=true no_fake_playback=true  isolated_instances=true active_shared_film=true saved=true")
	quit(0)
