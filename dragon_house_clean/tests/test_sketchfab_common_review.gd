extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var bank=B.new()
	assert(bank.initialize(),bank.error)
	assert(bank.sketchfab_common_enabled)
	var w=W.new()
	w.seed_world()
	var room:Dictionary=w.get_room(-2,0)
	var nav=N.new()
	nav.configure(bank.layouts)
	var row:Dictionary=bank.variant("common",3)
	assert(row["preserve_existing_runtime_geometry"].is_empty())
	var parent:=Node3D.new()
	root.add_child(parent)
	parent.set_meta("room_id",room["id"])
	assert(bank.populate(parent,"common",3,func(_z):return 1.0)>0)
	var hearth:Node3D=parent.get_node("common_r3_animated_hearth_review")
	var machine:Node3D=parent.get_node("common_r3_steampunk_machine_review")
	var table:Node3D=parent.get_node("common_r3_service_table_review")
	assert(hearth!=null and machine!=null and table!=null)
	assert(bool(hearth.get_meta("fire_playing",false)))
	var player:AnimationPlayer=null
	for node in hearth.find_children("*","AnimationPlayer",true,false):
		if node.has_animation("Fire"):player=node
	assert(player!=null and player.is_playing())
	assert(player.get_animation("Fire").get_track_count()==25)
	player.advance(0.25)
	assert(player.current_animation_position>0.0)
	assert(not nav.clear(room,Vector2(-0.35,-1.41)))
	assert(not nav.clear(room,Vector2(-6.4,-0.48)))
	assert(nav.clear(room,Vector2(-6.4,0.24)))
	var routes:=0
	for spot in nav.candidate_spots(room):
		for side in [-1,1]:
			var a:=Vector2(float(side)*7.12,1.50)
			var path:Array=nav.path(room,a,spot["offset"])
			assert(not path.is_empty(),str(spot["id"]))
			for b in path:
				assert(nav.segment_clear(room,a,b) and nav.sampled_segment_clear(room,a,b),str([spot["id"],a,b]))
				a=b
			routes+=1
	assert(nav.cup_slots(room).size()>=2)
	parent.free()
	print("SKETCHFAB_COMMON_REVIEW_PASS routes=",routes," fire_tracks=25 coffee_support=true")
	quit(0)
