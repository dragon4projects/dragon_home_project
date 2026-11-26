extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const D=preload("res://scripts/depth7_layout.gd")
const L=preload("res://scripts/life.gd")
const R=preload("res://scripts/asset_bank_resolver.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var n=N.new();n.configure({"library/R3":D.convert(b.layouts["library/R3"],"library/R3")})
 var w=W.new();w.canonical_house_seed=true;w.save_path="user://qa_hunt.json";w.seed_world()
 var room:Dictionary=w.matching_rooms(["library"])[0];room["depth7"]=true
 var c:Vector3=w.room_center_pos(room)
 assert(w.register_creature("QA_MOUSE","Mouse",room.id,"npc_mouse_gray"))
 var a:Dictionary=w.residents.MANJKA
 a.merge({"room_id":room.id,"level":room.level,"x":c.x-3,"z":1.5,"visual_y":c.y,"phase":"idle"},true)
 var m:Dictionary=w.creatures.QA_MOUSE
 m.merge({"x":c.x,"z":1.5,"visual_y":c.y,"phase":"idle"},true)
 var l=L.new();l.candidate_navigation=n;l.setup(w)
 assert(l.creature_runtime.try_begin_hunt(a))
 var initial:Vector2=Vector2(a.x,a.z)
 for i in range(8):
  w.sim_clock+=.125;l.creature_runtime._tick_hunt(.125)
 assert(Vector2(a.x,a.z).distance_to(initial)>.5)
 assert(w.save_world())
 var copy=W.new();copy.canonical_house_seed=true;copy.save_path=w.save_path;assert(copy.load_or_seed())
 # Main initializes the explicit depth7 layout flags before life.setup.
 copy.room_by_id(room.id)["depth7"]=true
 l=L.new();l.candidate_navigation=n;l.setup(copy);w=copy;a=w.residents.MANJKA;m=w.creatures.QA_MOUSE
 assert(a.phase=="hunt" and m.phase=="flee")
 var caught:=false
 var hold_restored:=false
 for i in range(200):
  w.sim_clock+=.125;l.creature_runtime._tick_hunt(.125)
  for actor in [a,m]:assert(n.clear(room,Vector2(actor.x-c.x,actor.z)))
  if m.phase=="caught":
   caught=true
   assert(Vector2(a.x,a.z).distance_to(Vector2(m.x,m.z))<=.28)
   if not hold_restored:
    assert(w.save_world())
    var again=W.new();again.canonical_house_seed=true;again.save_path=w.save_path;assert(again.load_or_seed())
    again.room_by_id(room.id)["depth7"]=true
    l=L.new();l.candidate_navigation=n;l.setup(again);w=again;a=w.residents.MANJKA;m=w.creatures.QA_MOUSE
    assert(a.phase=="hunt" and a.hunt_stage=="hold" and m.phase=="caught")
    hold_restored=true
  if a.phase!="hunt":break
 assert(caught and hold_restored and m.active and m.phase=="idle" and a.phase=="idle")
 var capture_count:=0
 for j in w.journal:
  if j.event=="MANKA_MOUSE_CAUGHT":capture_count+=1
 assert(capture_count==1)
 assert(not l.creature_runtime.try_begin_hunt(a))
 # Explicit invalidation never strands the mouse or overwrites a new route.
 a["hunt_next_at"]=0.0
 assert(l.creature_runtime.try_begin_hunt(a))
 a["phase"]="travel";a["intent"]="PURPOSEFUL_EXPLORE"
 l.creature_runtime._tick_hunt(.125)
 assert(a.phase=="travel" and a.intent=="PURPOSEFUL_EXPLORE" and m.phase=="idle" and not m.has("hunted_by"))
 var r=R.new();assert(r.initialize());assert(r.install_depth7_intake()==22)
 assert(r.manka_frame_count("CHASE_RIGHT")==6)
 for i in range(6):assert(r.manka_texture("CHASE_RIGHT",i)!=null)
 print("DEPTH7_MANKA_HUNT_PASS chase=true reload=true contact=true released_alive=true hold_reload=true replan_releases=true frames=6")
 quit()
