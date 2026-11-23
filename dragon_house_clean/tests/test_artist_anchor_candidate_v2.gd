extends SceneTree
const Inspector = preload("res://scripts/artist_anchor_candidate_v2.gd")

func _initialize() -> void:
	call_deferred("run")

func _by_id(items:Array,id:String)->Dictionary:
	for item in items:
		if str(item.get("id",""))==id:
			return item
	return {}

func run()->void:
	var inspector=Inspector.new()
	var report:Dictionary=inspector.inspect(
		"res://data/asset_proposals/TEEA_INT_20261122_003_furniture_anchors_candidate.json")
	assert(bool(report.get("valid",false)),str(report.get("errors",[])))
	assert(report.get("approved",true)==false)
	assert(report.get("integrated",true)==false)
	assert(int(report.get("station_count",-1))==7)
	assert(int(report.get("non_station_furniture_count",-1))==7)
	assert(report.get("semantic_mappings",[]).size()==5)

	var rooms:Dictionary=report["normalized_room_variants"]
	assert(rooms["arrival/R1"].is_empty())
	assert(rooms["corridor/R1"].is_empty())

	var music:Dictionary=_by_id(rooms["music/R1"],"music_listen_chair_seat_a")
	assert(not music.is_empty())
	assert(music["kind"]=="seat")
	assert(music["pose_hint"]=="RELAXED_SIT")
	assert(is_equal_approx(float(music["x"]),0.55))
	assert(is_equal_approx(float(music["z"]),-0.4742))

	var cinema_a:Dictionary=_by_id(rooms["cinema/R1"],"cinema_sofa_seat_a")
	var cinema_b:Dictionary=_by_id(rooms["cinema/R1"],"cinema_sofa_seat_b")
	assert(cinema_a["kind"]=="seat" and cinema_b["kind"]=="seat")
	assert(cinema_a["pose_hint"]=="RELAXED_SIT" and cinema_b["pose_hint"]=="RELAXED_SIT")

	var artifact:Dictionary=_by_id(rooms["artifact/R1"],"artifact_cabinet_view")
	assert(artifact["kind"]=="standing")
	assert(artifact["pose_hint"]=="VIEW")

	var workshop:Dictionary=_by_id(rooms["workshop/R1"],"workshop_bench_work")
	assert(workshop["kind"]=="work")
	assert(workshop["pose_hint"]=="USE")

	print("ARTIST_ANCHOR_V2_REVIEW_PASS stations=7 obstacles=7 mappings=5 approved=false integrated=false")
	quit(0)
