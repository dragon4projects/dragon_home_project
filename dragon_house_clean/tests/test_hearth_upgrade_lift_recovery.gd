extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
const S=preload("res://scripts/room_stations.gd")
class CameraFixture extends "res://scripts/main.gd":
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var w=W.new()
	w.canonical_house_seed=true
	w.save_path="user://hearth_upgrade_lift_qa.json"
	w.seed_world()
	w.sim_clock=1000.0
	var bank=B.new()
	assert(bank.initialize(true))
	bank.apply_architecture_layouts()
	var nav=N.new()
	nav.configure(bank.layouts)
	var station=S.new()
	station.candidate_navigation=nav
	for a in w.residents.values():a["active"]=false
	var hearth:Dictionary=w.room_by_id("ROOM_0027")
	var living:Dictionary=w.matching_rooms(["artifact"])[0]
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	var rider:Dictionary=w.residents["RES_03"]
	var c:Vector3=w.room_center_pos(hearth)
	# Old chair approach is the actual pre-V2 measurement. Stable ID survived,
	# but the old point must no longer authorize the old station.
	a.merge({"active":true,"room_id":hearth.id,"level":hearth.level,"x":c.x-2.6,"z":0.632194,"visual_y":c.y,"phase":"perform","intent":"REST","station_room_id":hearth.id,"station_slot":0,"station_anchor_id":"common_r3_p3_chair_center.seat_1","station_point":[-2.6,0.632194],"until":1400.0},true)
	var claim:Dictionary=station.single(w,b,living,"PURPOSEFUL_EXPLORE")
	assert(not claim.is_empty())
	var bp:Vector3=w.room_local_to_world(living,claim.offset)
	b.merge({"active":true,"room_id":living.id,"level":living.level,"x":bp.x,"z":bp.z,"visual_y":bp.y,"phase":"perform","intent":"PURPOSEFUL_EXPLORE","until":1400.0},true)
	station.commit_claim(b,claim)
	var lower:Dictionary=w.get_room(0,0)
	var upper:Dictionary=w.get_room(0,1)
	var top:Dictionary=w.get_room(0,2)
	var at:Vector3=w.room_center_pos(lower)+Vector3(-0.52,1.0,-0.75)
	var uc:Vector3=w.room_center_pos(upper)
	var tc:Vector3=w.room_center_pos(top)
	rider.merge({"active":true,"room_id":lower.id,"level":lower.level,"x":at.x,"visual_y":at.y,"z":at.z,"phase":"travel","intent":"PURPOSEFUL_EXPLORE","station_room_id":hearth.id,"station_slot":0,"station_anchor_id":"removed_station","station_point":[0.0,0.0],"waypoint_index":0,"waypoints":[{"kind":"lift","room_id":upper.id,"position":[uc.x,uc.y,0.0]},{"kind":"lift","room_id":top.id,"position":[tc.x,tc.y,0.0]},{"kind":"station","room_id":hearth.id,"position":[c.x,c.y,0.0]}],"canonical_lift_slot":{"shaft":"0","index":0},"canonical_lift_boarded":true,"until":1400.0},true)
	w.runtime_state["teea008_navigation_initialized"]=true
	w.runtime_state["teea008_geometry_revision"]="CANONICAL_SOCIAL_INTERIOR_20261125_V1|LIBRARY_GALLERY_V1|MEDIA_WORK_V1|GUEST_DISPLAY_V1"
	assert(w.save_world())
	var loaded=W.new()
	loaded.canonical_house_seed=true
	loaded.save_path=w.save_path
	assert(loaded.load_or_seed())
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(loaded)
	a=loaded.residents["RES_01"]
	b=loaded.residents["RES_02"]
	rider=loaded.residents["RES_03"]
	assert(a.phase=="idle" and not a.has("station_slot"))
	assert(b.phase=="perform" and b.station_anchor_id==claim.anchor_id and float(b.until)==1400.0)
	assert(rider.phase=="travel" and rider.has("station_replan_lift_pending"))
	assert(is_equal_approx(float(rider.visual_y),at.y))
	assert(life.canonical_lifts.occupied["0"][0]=="RES_03")
	# Run the real FOLLOW transform on every movement step, without loading
	# all of the art assets. The camera must not mutate physical state.
	var scene=CameraFixture.new()
	root.add_child(scene)
	scene.world=loaded
	scene.life=life
	scene.architecture_review=true
	scene.room_root=Node3D.new()
	scene.add_child(scene.room_root)
	scene.camera=Camera3D.new()
	scene.add_child(scene.camera)
	scene.semantic_view.install(loaded,"FOLLOW")
	scene.semantic_view.all_levels_visible=true
	scene.follow_id="RES_03"
	scene.current_mode="FOLLOW"
	scene.zoom=10.0
	scene.zoom_current=10.0
	scene.desired_focus=at+Vector3.UP
	scene.smooth_focus=scene.desired_focus
	var first_focus:Vector3=scene.smooth_focus
	var prev:Vector3=at
	for step in range(100):
		life._move(rider,0.1)
		var now:=Vector3(float(rider.x),float(rider.visual_y),float(rider.z))
		assert(now.distance_to(prev)<=0.23)
		prev=now
		var before:Dictionary=rider.duplicate(true)
		scene.apply_camera(0.1)
		assert(rider==before)
		assert(scene.camera.global_position.is_finite())
		if rider.phase=="idle":break
	assert(rider.phase=="idle" and rider.room_id==upper.id and is_equal_approx(float(rider.visual_y),uc.y))
	assert(not rider.has("station_replan_lift_pending") and not rider.has("teea008_geometry_replan_pending"))
	assert(not rider.has("canonical_lift_slot") and life.canonical_lifts.occupied["0"].is_empty())
	assert(scene.smooth_focus.y>first_focus.y+1.0)
	assert(scene.semantic_view.level==int(upper.level))
	# An owner-private room may have a public frontage. Freeze on entry,
	# rather than following hidden coordinates inside the room.
	var private:Dictionary=loaded.room_by_id(str(rider.home_room_id))
	assert(not loaded.public_cutaway_allowed(private) and loaded.allows_transit(private))
	var pc:Vector3=loaded.room_center_pos(private)
	var saved:Dictionary=rider.duplicate(true)
	rider.merge({"room_id":private.id,"level":private.level,"x":pc.x,"visual_y":pc.y,"z":-0.5,"phase":"perform"},true)
	var frozen:Vector3=scene.desired_focus
	for i in range(5):scene.apply_camera(0.1)
	assert(scene.desired_focus==frozen)
	rider["x"]=pc.x+1.0
	scene.apply_camera(0.1)
	assert(scene.desired_focus==frozen)
	rider["phase"]="travel"
	rider["z"]=1.54
	scene.apply_camera(0.1)
	assert(scene.desired_focus!=frozen)
	rider.clear()
	rider.merge(saved)
	assert(life._migrate_review_geometry(true)==0)
	assert(loaded.save_world())
	print("HEARTH_UPGRADE_LIFT_RECOVERY_PASS unaffected_commitment=true next_landing=true idempotent=true follow_movement=true private_focus_frozen=true")
	quit(0)
