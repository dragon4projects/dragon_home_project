extends SceneTree
const A=preload("res://scripts/asset_bank_resolver.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const W=preload("res://scripts/world_model.gd")
const S=preload("res://scripts/room_stations.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var banks=A.new()
 assert(banks.initialize())
 var bank=B.new()
 assert(bank.initialize(true))
 bank.apply_architecture_layouts()
 var nav=N.new()
 nav.configure(bank.layouts)
 var w=W.new()
 w.canonical_house_seed=true
 w.seed_world()
 var actor:Dictionary=w.residents.RES_07
 actor["teea008_pose_wardrobe"]="HOME"
 actor["visual_wardrobe"]="HOME"
 var remap:Dictionary={"IDLE_N":"IDLE_SW","IDLE_S":"IDLE_NE","IDLE_E":"IDLE_NW","IDLE_W":"IDLE_SE","IDLE_NE":"IDLE_W","IDLE_NW":"IDLE_SW","IDLE_SW":"IDLE_N","IDLE_SE":"IDLE_E"}
 for state in remap:
  var path:String=banks._normalize_frame(banks._entry("RES_07","HOME",state).frames[0])
  assert(path.ends_with("/"+remap[state]+"/0001.png"),str([state,path]))
  assert(banks.texture_for("RES_07","HOME",state,0)!=null)
 var profile:Dictionary=nav.pose_profile(actor,"IDLE_S")
 var hand:Dictionary=nav.hand_contact(actor,"IDLE_S",0)
 assert(profile.path==banks._normalize_frame(banks._entry("RES_07","HOME","IDLE_S").frames[0]))
 assert(hand.path==profile.path and hand.sha256==profile.sha256 and hand.hand_px==[293.0,315.0])
 assert(nav.hand_profiles.size()==27)
 var cinema:Dictionary=w.matching_rooms(["cinema"])[0]
 for a in w.residents.values():a.active=false
 var stations=S.new()
 stations.candidate_navigation=nav
 var claim:Dictionary=stations.single(w,actor,cinema,"WATCH_FILM")
 assert(not claim.is_empty() and not claim.has("contact") and claim.kind=="standing")
 # No fictional calibration: real bank has no rear seated or reading pose.
 assert(nav.pose_profile(actor,"SIT_N").is_empty() and nav.pose_profile(actor,"READ").is_empty())
 # Test-only geometry contract. This is NOT a new approved sprite.
 var fixture:Dictionary=nav.pose_profile(actor,"RELAXED_SIT").duplicate(true)
 nav.pose_profiles.RES_07.states["SIT_N"]=fixture
 var rear_claim:Dictionary=stations.single(w,actor,cinema,"WATCH_FILM")
 assert(rear_claim.has("contact") and rear_claim.contact.state=="SIT_N" and rear_claim.kind=="seat")
 assert(not rear_claim.contact.has("seat_front_z"))
 var found:=false
 for spot in nav.candidate_spots(cinema):
  if spot.id!=rear_claim.anchor_id:continue
  var facing:Array=spot.candidate_contact.facing
  assert(float(facing[2])< -0.5)
  var front:Dictionary=spot.duplicate(true)
  front.candidate_contact.facing=[0.0,0.0,1.0]
  assert(nav.pose_contact(actor,front,"WATCH_FILM").is_empty())
  found=true
 assert(found)
 nav.pose_profiles.RES_07.states.erase("SIT_N")
 assert(banks.frame_count("RES_07","HOME","SIT_N")==0)
 print("VISUAL_POSE_DIRECTION_V2_PASS remaps=8 hand_profile_bound=true standing_fallback=true rear_contact_geometry=true absent_art_not_approved=true")
 quit(0)
