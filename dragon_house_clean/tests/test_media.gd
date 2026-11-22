extends SceneTree
const W = preload("res://scripts/world_model.gd")
const M = preload("res://scripts/media_runtime.gd")
func _initialize() -> void:
	var w = W.new()
	w.seed_world()
	w.media["books"] = [{"id": "book:test", "title": "Test fixture only"}]
	var m = M.new()
	m.setup(w)
	assert(m.available_books().size() == 1)
	assert(m.borrow("RES_01", "book:test", 100), "Borrow")
	assert(not m.borrow("RES_02", "book:test", 101), "Cannot borrow second physical copy")
	assert(m.available_books().is_empty())
	assert(m.read("RES_01", "book:test", 90.0))
	assert(m._lookup("books", "book:test")["progress_by_actor"]["RES_01"] == 90.0)
	assert(m.return_book("RES_01", "book:test"))
	assert(m.available_books().size() == 1)
	assert(m.borrow("RES_02", "book:test", 200))
	assert(m.drop_book("RES_02", "book:test", 201))
	assert(m.cleanup_abandoned(201 + 86399) == 0)
	assert(m.cleanup_abandoned(201 + 86400) == 1)
	assert(m.available_books().size() == 1)
	assert(not m.can_watch("RES_01", "missing", w.get_room(4, 0)["id"]))
	assert(not m.can_listen("RES_01", "missing", w.get_room(3, 0)["id"]))
	w.save_path = "user://test_media_world_only.json"
	w.sim_clock = 12345.75
	assert(w.save_world())
	var recovered = W.new()
	recovered.save_path = w.save_path
	recovered.load_or_seed()
	assert(is_equal_approx(recovered.sim_clock, 12345.75))
	assert(recovered.media["books"].size() == 1)
	assert(recovered.media["books"][0]["progress_by_actor"]["RES_01"] == 90.0)
	assert(recovered.get_room(6, 0).is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path))
	print("MEDIA_LIFECYCLE_TEST_PASS physical=1 conflict=denied overdue=24h persisted=yes")
	quit(0)

