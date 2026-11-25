extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/canonical_beverage_runtime.gd")
func _initialize()->void:
	var world=W.new()
	world.canonical_house_seed=true
	world.seed_world()
	var b=B.new()
	b.setup(world)
	assert(b.enabled and b.entries.size()==105)
	var empty:Dictionary={"drink_counts":{}}
	var opts:Array=b.weights(empty,"GENERIC","day")
	for row in opts:assert(float(row["final_weight"])==1.0)
	assert(b.learned_weight(4)==1.0 and b.learned_weight(5)>1.0)
	var learned:Dictionary={"drink_counts":{"CAPPUCCINO":30}}
	opts=b.weights(learned,"GENERIC","day")
	# Cumulative prefix array keeps the 100k reference simulation cheap.
	var cumulative:Array=[]
	var total:=0.0
	for row in opts:
		total+=float(row["final_weight"])
		cumulative.append(total)
	var rng:=RandomNumberGenerator.new()
	rng.seed=10530
	var favorite:=0
	for i in range(100000):
		var roll:float=rng.randf()*total
		var ix:int=mini(cumulative.bsearch(roll),opts.size()-1)
		if str(opts[ix]["drink_id"])=="CAPPUCCINO":favorite+=1
	assert(favorite>=73500 and favorite<=76500,str(favorite))
	for spec in [["READING","CAPPUCCINO","VODKA"],["SISTERS_SOCIAL","RED_WINE","CAPPUCCINO"],["MORNING","CAPPUCCINO","VODKA"],["BRUNCH","COCKTAIL_MIMOSA","COCKTAIL_NEGRONI"],["AFTER_DINNER","COGNAC","VODKA"]]:
		var map:Dictionary={}
		for row in b.weights(empty,str(spec[0]),"day"):map[row["drink_id"]]=row["final_weight"]
		assert(float(map[spec[1]])>float(map[spec[2]]),str(spec))
	var actor_id: String="QA_DRINKER"
	world.objects["QA_CUP"]={"viewer_category":"cups","current_holder_id":actor_id}
	assert(b.fill_or_resume("QA_CUP",actor_id,"GENERIC","day",["COFFEE_NOOK","BAR"],"CAPPUCCINO"))
	var first:Dictionary=b.content("QA_CUP")
	var choice:String=str(first["choice_instance_id"])
	assert(int(b.history(actor_id)["total_choices"])==0)
	assert(not b.sip("QA_CUP","WRONG"))
	assert(b.sip("QA_CUP",actor_id))
	assert(float(first["remaining_ml"])==165.0)
	assert(int(b.history(actor_id)["drink_counts"]["CAPPUCCINO"])==1)
	assert(b.fill_or_resume("QA_CUP",actor_id,"GENERIC","day",["COFFEE_NOOK","BAR"],"VODKA"))
	assert(str(first["choice_instance_id"])==choice)
	assert(b.sip("QA_CUP",actor_id))
	assert(int(b.history(actor_id)["total_choices"])==1)
	var restored=B.new()
	restored.setup(world)
	assert(float(restored.content("QA_CUP")["remaining_ml"])==110.0)
	assert(restored.history(actor_id)["drink_counts"]["CAPPUCCINO"]==1)
	assert(not restored.can_use("QA_CUP","OTHER"))
	assert(restored.sip("QA_CUP",actor_id) and restored.sip("QA_CUP",actor_id))
	assert(float(first["remaining_ml"])==0.0)
	assert(restored.fill_or_resume("QA_CUP",actor_id,"GENERIC","day",["COFFEE_NOOK","BAR"],"VODKA"))
	restored.empty_cup("QA_CUP")
	assert(int(restored.history(actor_id)["total_choices"])==1)
	var f:=FileAccess.open(B.LOG_PATH,FileAccess.READ)
	assert(f!=null)
	var log:Array=[]
	while not f.eof_reached():
		var line:String=f.get_line()
		if line!="":log.append(JSON.parse_string(line))
	assert(log.size()==2)
	assert(bool(log[0]["first_sip_success"]) and not bool(log[1]["first_sip_success"]))
	print("CANONICAL_BEVERAGE_PASS catalog=105 monte_carlo_favorite=",favorite," partial_resume=true failed_not_learned=true log_rows=",log.size())
	quit(0)
