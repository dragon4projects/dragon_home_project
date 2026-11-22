extends SceneTree
const W = preload("res://scripts/world_model.gd")
const M = preload("res://scripts/media_runtime.gd")
func _initialize() -> void:
	var w = W.new()
	w.save_path = "user://test_reference_books_only.json"
	w.seed_world()
	var metadata: Array = [
		{"id":"REF_01","title":"Книга из облака","author":"Автор","status":"METADATA_ONLY","source":"test"},
		{"id":"REF_02","title":"Другой том","author":null,"status":"METADATA_ONLY","source":"test"},
		{"id":"NOT_ALLOWED","title":"Не подтверждено","author":"Автор","status":"DRAFT"}
	]
	assert(w.merge_reference_book_metadata(metadata)==2)
	assert(w.merge_reference_book_metadata(metadata)==0)
	var m = M.new()
	m.setup(w)
	assert(w.media["books"].size()==2)
	assert(w.media["books"][1]["author"]=="","Missing author stays blank, not string null")
	assert(m.available_books().is_empty(),"Cloud metadata is not physically shelved")
	assert(not m.borrow("RES_01","REF_01"),"No phantom book borrowing")
	assert(w.media["books"][0]["catalog_only"])
	assert(w.media["books"][0]["location_room_id"]=="")
	var recovered = W.new()
	recovered.save_path = w.save_path
	recovered.load_or_seed()
	assert(recovered.media["books"].size()==2)
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+ext))
	print("BOOK_METADATA_TEST_PASS 2_catalog 0_physical 0_phantom_reads persisted")
	quit(0)

