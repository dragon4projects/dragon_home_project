extends SceneTree
const W = preload("res://scripts/world_model.gd")
func _initialize() -> void:
	var w = W.new()
	w.save_path = "user://test_safe_snapshot.json"
	var save_path: String = ProjectSettings.globalize_path(w.save_path)
	w.seed_world()
	w.sim_clock = 111.0
	assert(w.save_world(),"Initial valid snapshot")
	w.sim_clock = 222.0
	assert(w.save_world(),"Second write with retained backup")
	assert(FileAccess.file_exists(w.save_path+".bak"))
	var bad := FileAccess.open(w.save_path,FileAccess.WRITE)
	bad.store_string("{bad JSON")
	bad.close()
	var recovered = W.new()
	recovered.save_path = w.save_path
	recovered.load_or_seed()
	assert(is_equal_approx(recovered.sim_clock,111.0),"Must recover previous snapshot on corruption")
	assert(recovered.residents.size()==25)
	assert(recovered.residents["RES_22"]["name"]=="Вея")
	assert(recovered.residents["RES_22"]["appearance_profile"]=="LISA_03")
	var good_backup_hash:String=FileAccess.get_sha256(w.save_path+".bak")
	assert(good_backup_hash!="")
	assert(recovered.save_world())
	assert(FileAccess.get_sha256(w.save_path+".bak")==good_backup_hash,"Recovery save must not replace a valid backup with corrupt primary")
	# A second torn write before the next checkpoint must still recover.
	bad=FileAccess.open(w.save_path,FileAccess.WRITE)
	bad.store_string("{second torn write")
	bad.close()
	var final = W.new()
	final.save_path = w.save_path
	final.load_or_seed()
	assert(is_equal_approx(final.sim_clock,111.0))
	assert(final.save_world())
	assert(FileAccess.get_sha256(w.save_path+".bak")==good_backup_hash)
	final.sim_clock=333.0
	assert(final.save_world())
	assert(not final._read_snapshot(w.save_path+".bak").is_empty())
	assert(is_equal_approx(float(final._read_snapshot(w.save_path+".bak")["sim_clock"]),111.0))
	for suffix in [
		"",".bak",".tmp",
		".world_events_v1.json",
		".world_events_v1.json.bak",
		".world_events_v1.json.tmp",
		".world_events_v1.json.corrupt"
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+suffix))
	print("SNAPSHOT_RECOVERY_TEST_PASS backup=restored roster=24")
	quit(0)

