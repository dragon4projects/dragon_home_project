extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func verify(life,actor:Dictionary)->int:
	life._begin_candidate_plan(actor)
	var checked:=0
	for room in life.world.rooms:
		var id:String=str(room["id"])
		var old:Array=life.world.find_route(actor["room_id"],id,actor["id"])
		var new:Array=life.planning_routes.get(id,[])
		assert(old==new,str([actor["id"],id,old,new]))
		checked+=1
	life._end_candidate_plan()
	return checked
func run()->void:
	var w=W.new()
	w.seed_world()
	var nav=N.new()
	var rows:Dictionary={}
	var f:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	for row in JSON.parse_string(f.get_as_text())["items"]:rows[row["variant_id"]]=row
	nav.configure(rows)
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(w)
	var count:=0
	for actor in w.residents.values():
		if bool(actor.get("active",false)):
			count+=verify(life,actor)
	assert(life.planner_graph_rebuilds==1)
	assert(w.build_room(6,0,"library",2))
	count+=verify(life,w.residents["RES_01"])
	assert(life.planner_graph_rebuilds==2)
	var actor:Dictionary=w.residents["RES_01"]
	var room:Dictionary=w.get_room(-2,0)
	life.stations.begin_planning_snapshot()
	var slots:Array=life.stations.layout_for_world(w,room)
	assert(slots==life.stations.layout_for_world(w,room))
	life.stations.end_planning_snapshot()
	assert(life.stations.planning_layouts.is_empty())
	print("TEEA008_PLANNER_CACHE_PASS routes=",count," graph_rebuilds=",life.planner_graph_rebuilds)
	quit(0)
