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
	w.media["films"]=[{"id":"QA_A","title":"QA A","file_path":"user://qa_media.ogv"},{"id":"QA_B","title":"QA B","file_path":"user://qa_media.ogv"},{"id":"QA_META","title":"metadata only"}]
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
	assert(binding.resolve(a["id"],id)["id"]=="QA_B")
	assert(binding.choose_film(a["id"],"RES_02")["id"]=="QA_B")
	actor["phase"]="idle"
	assert(binding.resolve(a["id"],id)["id"]=="QA_A")
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
	print("TEEA008_MEDIA_BINDINGS_PASS isolated_instances=true active_shared_film=true saved=true")
	quit(0)
