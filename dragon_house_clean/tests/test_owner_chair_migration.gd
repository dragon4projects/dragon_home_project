extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
const S=preload("res://scripts/room_stations.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path="user://qa_owner_chair_migration.json"
 assert(w.load_or_seed())
 var bank=B.new()
 assert(bank.initialize(true))
 bank.apply_architecture_layouts()
 var nav=N.new()
 nav.configure(bank.layouts)
 var kitchen:Dictionary=w.matching_rooms(["rest"])[0]
 var cinema:Dictionary=w.matching_rooms(["artifact"])[0]
 for a in w.residents.values():a.active=false
 var actor:Dictionary=w.residents.RES_01
 var other:Dictionary=w.residents.RES_02
 var old:Vector2=Vector2(2.0,-0.61712)
 var p:Vector3=w.room_local_to_world(kitchen,old)
 actor.merge({"active":true,"room_id":kitchen.id,"level":kitchen.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":"REST","station_room_id":kitchen.id,"station_slot":0,"station_anchor_id":"rest_r3_armchair.seat_1","station_point":[old.x,old.y],"until":200.0},true)
 var s=S.new()
 s.candidate_navigation=nav
 var claim:Dictionary=s.single(w,other,cinema,"PURPOSEFUL_EXPLORE")
 assert(not claim.is_empty())
 p=w.room_local_to_world(cinema,claim.offset)
 other.merge({"active":true,"room_id":cinema.id,"level":cinema.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":"PURPOSEFUL_EXPLORE","until":200.0},true)
 s.commit_claim(other,claim)
 w.sim_clock=100.0
 w.runtime_state["teea008_navigation_initialized"]=true
 w.runtime_state["teea008_geometry_revision"]="CANONICAL_SOCIAL_INTERIOR_20261125_V2_HEARTH|LIBRARY_GALLERY_V2_READING|MEDIA_WORK_V1|GUEST_DISPLAY_V1|SOCIAL_ZONES_V3|CENTAUR_COMPOSITION_V2|OWNER_THEATRE_V1|OWNER_ROOM_CLUSTERS_V1"
 assert(w.save_world())
 var loaded=W.new()
 loaded.canonical_house_seed=true
 loaded.save_path=w.save_path
 assert(loaded.load_or_seed())
 var l=L.new()
 l.candidate_navigation=nav
 l.setup(loaded)
 var a:Dictionary=loaded.residents.RES_01
 var b:Dictionary=loaded.residents.RES_02
 assert(a.phase=="idle" and not a.has("station_anchor_id"))
 assert(nav.clear(kitchen,loaded.room_world_to_local(kitchen,Vector3(a.x,a.visual_y,a.z))))
 assert(b.phase=="perform" and b.station_anchor_id==claim.anchor_id and b.until==200.0)
 assert(loaded.runtime_state.teea008_geometry_revision.ends_with("|OWNER_CHAIR_V1"))
 var count:=0
 for row in loaded.journal:
  if row.event=="TEEA008_REVIEW_GEOMETRY_MIGRATED":count+=1
 assert(count==1)
 assert(loaded.save_world())
 var again=W.new()
 again.canonical_house_seed=true
 again.save_path=w.save_path
 assert(again.load_or_seed())
 var l2=L.new()
 l2.candidate_navigation=nav
 l2.setup(again)
 var after:=0
 for row in again.journal:
  if row.event=="TEEA008_REVIEW_GEOMETRY_MIGRATED":after+=1
 assert(after==count and again.residents.RES_02.until==200.0)
 print("OWNER_CHAIR_MIGRATION_PASS stale_claim_replanned=true unaffected_commitment=true idempotent=true")
 quit(0)
