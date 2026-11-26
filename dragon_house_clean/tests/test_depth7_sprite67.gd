extends SceneTree
const R=preload("res://scripts/asset_bank_resolver.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const L=preload("res://scripts/depth7_layout.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var r=R.new();assert(r.initialize());assert(r.install_depth7_intake()==22)
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 for key in L.SOCIAL_KEYS+L.FUNCTION_KEYS+L.GUEST_KEYS:b.layouts[key]=L.convert(b.layouts[key],key)
 var file:=FileAccess.open("res://data/depth7_hearth_layout.json",FileAccess.READ);b.layouts["common/R3"]=JSON.parse_string(file.get_as_text())
 var n=N.new();n.configure(b.layouts);assert(n.install_depth7_pose_intake()==14)
 var count:=0;var directions:Dictionary={}
 for actor_id in ["RES_04","RES_08","RES_07"]:
  var w:String="CITY" if actor_id=="RES_08" else "HOME"
  var actor={"id":actor_id,"appearance_profile":r.manifest.residents[actor_id].appearance_profile,"teea008_pose_wardrobe":w}
  var successes:=0
  for key in ["common/R3","cinema/R3","library/R3","music/R3","rest_social_upper/R3"]:
   var room={"id":"QA","type":key.get_slice("/",0),"size_modules":3,"depth7":true}
   if key.begins_with("rest_social"):room["interior_variant"]=key.get_slice("/",0)
   for spot in n.candidate_spots(room):
    var intent:String="READ_BOOK" if actor_id=="RES_07" else ("WATCH_FILM" if key=="cinema/R3" else "REST")
    var contact:Dictionary=n.pose_contact(actor,spot,intent)
    if contact.is_empty():continue
    var state:String=contact.state
    if state=="SIT_E_OCCLUDED":continue
    assert(r.texture_for(actor_id,w,state,0)!=null)
    if state.begins_with("SIT_") or (actor_id=="RES_07" and state=="READ"):
     successes+=1;directions[state]=int(directions.get(state,0))+1
  assert(successes>0,actor_id)
  count+=successes
  print("SPRITE67_SEATS ",actor_id," contacts=",successes)
 for state in ["HOVER_IDLE","HOVER_MOVE_W","HOVER_MOVE_E","HOVER_REST"]:
  assert(r.creature_frame_count("npc_ai_magic_sphere",state)==4)
  for i in range(4):assert(r.creature_texture("npc_ai_magic_sphere",state,i)!=null)
 assert(r.frame_count("RES_07","HOME","IDLE_NW")==1)
 print("SPRITE67_CONTACT_PASS count=",count," directions=",directions," hover=16")
 quit(0)
