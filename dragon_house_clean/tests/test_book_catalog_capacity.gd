extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
class FixtureSlots:
	extends RefCounted
	func book_slots(room:Dictionary)->Array:
		if str(room.get("type",""))!="library":return []
		return [{"id":"QA_A","station_id":"QA_A","xyz":[0.1,0.7,0.2]},{"id":"QA_B","station_id":"QA_B","xyz":[0.5,0.7,0.2]}]
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.seed_world()
	w.save_path="user://book_catalog_qa_"+str(Time.get_ticks_usec())+".json"
	var m=M.new()
	m.candidate_navigation=FixtureSlots.new()
	m.setup(w)
	var result:Dictionary=m.install_canonical_book_catalog()
	assert(result["catalog"]==76)
	assert(result["physical"]==2)
	assert(w.media["books"].size()==76)
	assert(m.available_books().size()==2)
	assert(m.install_canonical_book_catalog()["catalog"]==0)
	assert(m.install_canonical_book_catalog()["physical"]==0)
	var numbered:=0
	for b in w.media["books"]:
		if int(b.get("series_index",0))>0:numbered+=1
		assert(b.get("preview_status","")=="UNAPPROVED_TYPOGRAPHIC_PLACEHOLDER_NOT_OFFICIAL_COVER")
	assert(numbered==54)
	assert(m._lookup("books","BOOK_WITCHER_09")["series_index"]==8)
	assert(m._lookup("books","BOOK_WITCHER_08").get("series_id","")=="")
	print("BOOK_CATALOG_PASS count=76 numbered=54 physical_capacity_respected=true")
	quit(0)
