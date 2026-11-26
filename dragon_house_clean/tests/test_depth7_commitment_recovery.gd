extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
const D=preload("res://scripts/depth7_layout.gd")
func _initialize()->void:call_deferred("run")
func restore(w,nav):
 assert(w.save_world())
 var copy=W.new();copy.canonical_house_seed=true;copy.save_path=w.save_path
 assert(copy.load_or_seed())
 var life=L.new();life.candidate_navigation=nav;life.setup(copy)
 return life
func run()->void:
 var bank=B.new();assert(bank.initialize(true));bank.apply_architecture_layouts()
 var row:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/depth7_hearth_layout.json"))
 D.append_hearth_services(row,bank.layouts["common/R3"])
 var nav=N.new();nav.configure({"common/R3":row})
 var w=W.new();w.canonical_house_seed=true;w.save_path="user://depth7_recovery_qa.json";w.seed_world()
 var room:Dictionary=w.get_room(-3,1)
 room["depth7"]=true
 for a in w.residents.values():a["active"]=false
 var a:Dictionary=w.residents["RES_01"];a["active"]=true
 var c:Vector3=w.room_center_pos(room)
 a.merge({"room_id":room.id,"level":room.level,"x":c.x,"z":1.5,"visual_y":c.y,"phase":"idle","teea008_pose_wardrobe":"HOME"},true)
 var l=L.new();l.candidate_navigation=nav;l.setup(w)
 l.candidate_cups.register_review_mugs()
 l.candidate_cups.beverages.forced_drinks[a.id]="RED_WINE"
 l._assign(a,{"room":room,"intent":"GET_COFFEE"})
 assert(a.get("cup_task_stage")=="fetch")
 for i in range(2000):
  l.clock+=.125;w.sim_clock=l.clock;l._move(a,.125)
  if a.get("cup_task_stage")=="serve":break
 assert(a.get("cup_task_stage")=="serve")
 var cup_id:String=a.cup_task_id
 var choice:String=a.drink_service_plan.choice_instance_id
 assert(l.candidate_cups.service_plan_valid(a))
 l=restore(w,nav);w=l.world;a=w.residents.RES_01
 assert(a.get("cup_task_stage")=="serve" and a.phase=="travel")
 assert(a.drink_service_plan.choice_instance_id==choice)
 for i in range(2000):
  l.clock+=.125;w.sim_clock=l.clock;l._move(a,.125)
  if a.get("cup_task_stage")=="hold":break
 assert(a.get("cup_task_stage")=="hold" and a.phase=="perform")
 var beverage=l.candidate_cups.beverages
 var volume:float=beverage.content(cup_id).remaining_ml
 assert(volume>0 and beverage.content(cup_id).choice_instance_id==choice)
 assert(beverage.sip(cup_id,a.id))
 var left:float=beverage.content(cup_id).remaining_ml
 var deadline:float=a.until
 l=restore(w,nav);w=l.world;a=w.residents.RES_01;beverage=l.candidate_cups.beverages
 assert(a.get("cup_task_stage")=="hold" and a.phase=="perform" and a.until==deadline)
 assert(beverage.content(cup_id).remaining_ml==left and beverage.history(a.id).total_choices==1)
 # A stale source coordinate must not produce a refill.
 var stale:Dictionary=beverage.plan_new(cup_id,a.id,"GENERIC","day",["BAR"],"RED_WINE")
 beverage.empty_cup(cup_id)
 a["drink_service_plan"]=stale;a["drink_service_approach"]=[0.0,1.5];a["drink_service_id"]="deleted_bar";a["cup_task_stage"]="serve"
 a["x"]=c.x;a["z"]=1.5
 assert(not l.candidate_cups.service_plan_valid(a,true))
 l._complete_drink_service(a)
 assert(float(beverage.content(cup_id).remaining_ml)==0 and a.drink_sips_left==0)
 # A still-valid rest claim retains its deadline on a geometry revision.
 var b:Dictionary=w.residents.RES_02;b["active"]=true;b["teea008_pose_wardrobe"]="SHORT"
 var claim:Dictionary=l.stations.single(w,b,w.room_by_id(room.id),"REST")
 assert(not claim.is_empty())
 var p:Vector3=w.room_local_to_world(room,claim.offset)
 b.merge({"room_id":room.id,"level":room.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":"REST","until":l.clock+100.0},true)
 l.stations.commit_claim(b,claim);l._begin_solo_habit_commitment(b)
 assert(b.has("solo_habit_commitment"))
 var habit:Dictionary=b.solo_habit_commitment.duplicate(true)
 w.runtime_state["teea008_geometry_revision"]=str(w.runtime_state["teea008_geometry_revision"]).trim_suffix("|DEPTH7_SERVICES_V1")
 l=restore(w,nav);w=l.world;b=w.residents.RES_02
 assert(b.phase=="perform" and b.station_anchor_id==claim.anchor_id and b.until==habit.ends_at)
 assert(b.solo_habit_commitment==habit)
 print("DEPTH7_COMMITMENT_RECOVERY_PASS service_travel=true held_volume=true stale_source_rejected=true rest_deadline=true")
 quit()
