extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
const H=preload("res://scripts/learned_habits.gd")
const M=preload("res://scripts/media_runtime.gd")
const D=preload("res://scripts/canonical_beverage_runtime.gd")
func _initialize():call_deferred("run")
func run():
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path="user://habit_credit_"+str(Time.get_ticks_usec())+".json"
 w.seed_world()
 var bank=B.new()
 assert(bank.initialize(true))
 bank.apply_architecture_layouts()
 var nav=N.new()
 nav.configure(bank.layouts)
 for a in w.residents.values():a.active=false
 var actor:Dictionary=w.residents.RES_01
 var room:Dictionary=w.room_by_id("ROOM_0027")
 var center:Vector3=w.room_center_pos(room)
 actor.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":center.x,"z":1.5,"visual_y":center.y,"phase":"idle","habits":{}},true)
 w.runtime_state["teea008_navigation_initialized"]=true
 w.sim_clock=1000.0
 var life=L.new()
 life.candidate_navigation=nav
 life.setup(w)
 life._assign(actor,{"room":room,"intent":"WATCH_FIRE"})
 assert(actor.phase=="travel" and actor.habits.is_empty())
 life.stations.release(actor)
 actor.phase="idle"
 actor.waypoints=[]
 assert(not life._finish_solo_habit_commitment(actor))
 life._assign(actor,{"room":room,"intent":"WATCH_FIRE"})
 for i in range(500):
  life.clock+=0.125
  w.sim_clock=life.clock
  life._move(actor,0.125)
  if actor.phase=="perform":break
 assert(actor.phase=="perform" and actor.has("solo_habit_commitment") and actor.habits.is_empty())
 assert(not life._finish_solo_habit_commitment(actor))
 assert(w.save_world())
 var copy=W.new()
 copy.canonical_house_seed=true
 copy.save_path=w.save_path
 assert(copy.load_or_seed())
 life=L.new()
 life.candidate_navigation=nav
 life.setup(copy)
 actor=copy.residents.RES_01
 assert(actor.has("solo_habit_commitment") and actor.habits.is_empty())
 life.clock=float(actor.until)
 copy.sim_clock=life.clock
 assert(life._finish_solo_habit_commitment(actor))
 assert(not life._finish_solo_habit_commitment(actor))
 assert(actor.habit_success.WATCH_FIRE.count==1 and is_equal_approx(actor.habits.WATCH_FIRE,0.012))
 assert(is_equal_approx(H.strength(actor,"WATCH_FIRE",life.clock+H.DECAY_HALF_LIFE),0.006))
 assert(copy.save_world())
 var again=W.new()
 again.canonical_house_seed=true
 again.save_path=copy.save_path
 assert(again.load_or_seed())
 assert(again.residents.RES_01.habit_success.WATCH_FIRE.count==1)
 assert(not again.residents.RES_01.has("solo_habit_commitment"))
 # First successful sip only, including failed choice and partial refill.
 var drinks=D.new()
 drinks.setup(again)
 var id:String="RES_01"
 again.objects["QA_CUP"]={"viewer_category":"cups","current_holder_id":id}
 assert(drinks.fill_or_resume("QA_CUP",id,"GENERIC","day",["COFFEE_NOOK","BAR"],"CAPPUCCINO"))
 assert(not again.residents[id].habits.has("GET_COFFEE"))
 assert(not drinks.sip("QA_CUP","WRONG"))
 assert(drinks.sip("QA_CUP",id) and drinks.sip("QA_CUP",id))
 assert(again.residents[id].habit_success.GET_COFFEE.count==1)
 drinks.empty_cup("QA_CUP")
 assert(drinks.fill_or_resume("QA_CUP",id,"GENERIC","day",["COFFEE_NOOK","BAR"],"CAPPUCCINO"))
 drinks.empty_cup("QA_CUP")
 assert(again.residents[id].habit_success.GET_COFFEE.count==1)
 print("COMPLETED_HABIT_CREDIT_PASS route_cancel=true actual_arrival=true reload_once=true decay=true first_sip=true")
 quit(0)
