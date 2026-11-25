extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:
	var w=W.new()
	var result:Dictionary=w._read_cinema_batch("res://data/filmix_bundle/filmix_catalog.json",false)
	assert(result["ok"] and result["rows"].size()==187)
	assert(w._ensure_bundled_cinema_previews(result["rows"]))
	var checked:Dictionary=w._read_cinema_batch("res://data/filmix_bundle/filmix_catalog.json",true)
	assert(checked["ok"] and checked["rows"].size()==187)
	assert(w._ensure_bundled_cinema_previews(checked["rows"]),"idempotent verified cache")
	var film_count:=0
	var series_count:=0
	var known_films:=0
	for row in checked["rows"]:
		assert(row["simulation_only"] and row["file_path"]=="")
		if row["media_type"]=="film":
			film_count+=1
			if float(row.get("runtime_seconds",0))>0:known_films+=1
		else:series_count+=1
	assert(film_count==92 and series_count==95 and known_films>=26)
	print("FILMIX_BUNDLE_PASS catalog=187 posters=187 verified_cache=true")
	quit(0)
