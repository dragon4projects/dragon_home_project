extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/canonical_beverage_runtime.gd")
func _initialize()->void:
 var w=W.new()
 w.canonical_house_seed=true
 w.seed_world()
 var b=B.new()
 b.setup(w)
 var id="QA_DRINKER"
 w.objects["QA_CUP"]={"viewer_category":"cups","current_holder_id":id}
 w.sim_clock=100.0
 assert(b.autonomous_visit_ready(id,100.0))
 assert(b.fill_or_resume("QA_CUP",id,"GENERIC","day",["COFFEE_NOOK","BAR"],"CAPPUCCINO"))
 assert(b.autonomous_visit_ready(id,100.0))
 assert(not b.sip("QA_CUP","WRONG"))
 assert(b.sip("QA_CUP",id))
 assert(not b.autonomous_visit_ready(id,999.0))
 assert(b.autonomous_visit_ready(id,1000.0))
 w.sim_clock=105.0
 assert(b.sip("QA_CUP",id))
 assert(b.history(id)["total_choices"]==1)
 var restored=B.new()
 restored.setup(w)
 assert(not restored.autonomous_visit_ready(id,1004.0))
 assert(restored.autonomous_visit_ready(id,1005.0))
 assert(restored.fill_or_resume("QA_CUP",id,"GENERIC","day",["COFFEE_NOOK","BAR"],"VODKA"))
 assert(restored.history(id)["total_choices"]==1)
 assert(restored.content("QA_CUP")["remaining_ml"]==110.0)
 print("I94_BEVERAGE_PACING_PASS interval=900 active_sips=true partial_resume=true persisted=true")
 quit(0)
