extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const B=preload("res://scripts/canonical_beverage_runtime.gd")
const SAVE="user://decision_rng_checkpoint.json"
func _initialize()->void:call_deferred("run")
func sample(rng:RandomNumberGenerator)->Array:
 var values:Array=[]
 for i in range(32):values.append(rng.randi())
 return values
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path=SAVE
 assert(w.load_or_seed())
 var l=L.new()
 l.setup(w)
 var b=B.new()
 b.setup(w)
 assert(b.enabled)
 for rng in [l.rng,l.creature_runtime.rng,b.rng]:
  for i in range(37):rng.randi()
 var state:Dictionary={}
 for domain in W.RNG_STREAM_SEEDS:
  state[domain]=str(w.decision_rng(domain).state)
 assert(w.save_world())
 assert(w.runtime_state.decision_rng_v1==state)
 assert(w.runtime_state.beverages.rng_state==state.beverages)
 var expected:Dictionary={}
 for domain in W.RNG_STREAM_SEEDS:expected[domain]=sample(w.decision_rng(domain))
 var r=W.new()
 r.canonical_house_seed=true
 r.save_path=SAVE
 assert(r.load_or_seed())
 var next=L.new()
 next.setup(r)
 var drinks=B.new()
 drinks.setup(r)
 assert(next.rng==r.decision_rng("life") and next.creature_runtime.rng==r.decision_rng("creatures") and drinks.rng==r.decision_rng("beverages"))
 for domain in W.RNG_STREAM_SEEDS:
  assert(str(r.decision_rng(domain).state)==state[domain])
  assert(sample(r.decision_rng(domain))==expected[domain])
 var advanced:String=str(next.rng.state)
 next.setup(r)
 assert(str(next.rng.state)==advanced)
 var creature_state:String=str(next.creature_runtime.rng.state)
 var beverage_state:String=str(drinks.rng.state)
 next.rng.randi()
 assert(str(next.creature_runtime.rng.state)==creature_state and str(drinks.rng.state)==beverage_state)
 var roll_state:String=str(drinks.rng.state)
 drinks.simulate("RES_01","GENERIC",25)
 assert(str(drinks.rng.state)==roll_state)
 # Legacy beverage-only save: the exact old PCG state is restored.
 var legacy=W.new()
 legacy.canonical_house_seed=true
 legacy.seed_world()
 legacy.runtime_state["beverages"]={"cups":{},"preferences":{},"serial":0,"rng_state":"-9223372036854775808"}
 var old=B.new()
 old.setup(legacy)
 assert(str(old.rng.state)=="-9223372036854775808")
 assert(W._valid_rng_state("9223372036854775807") and not W._valid_rng_state("9223372036854775808"))
 assert(not W._valid_rng_state(123) and not W._valid_rng_state("1.0"))
 # Corrupt only the RNG state; backup must be preferred to silently reseeding.
 assert(r.save_world())
 var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
 doc.runtime_state.decision_rng_v1.life="9223372036854775808"
 var f:=FileAccess.open(SAVE,FileAccess.WRITE)
 f.store_string(JSON.stringify(doc))
 f.close()
 var recovered=W.new()
 recovered.canonical_house_seed=true
 recovered.save_path=SAVE
 assert(recovered.load_or_seed() and recovered.load_status=="RECOVERED_BACKUP")
 for domain in W.RNG_STREAM_SEEDS:assert(str(recovered.decision_rng(domain).state)==state[domain])
 print("DECISION_RNG_CHECKPOINT_PASS domains=3 draws=96 exact_signed64=true legacy=true repeated_setup=true isolation=true invalid_primary_backup=true")
 quit(0)
