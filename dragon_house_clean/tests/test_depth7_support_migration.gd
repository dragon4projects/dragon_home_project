extends SceneTree
const W=preload("res://scripts/world_model.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const L=preload("res://scripts/depth7_layout.gd")
const M=preload("res://scripts/depth7_support_migration.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var world=W.new();world.canonical_house_seed=true;world.save_path="user://qa_depth7_support.json";world.seed_world()
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var old=N.new();old.configure(b.layouts.duplicate(true))
 var rows:Dictionary=b.layouts.duplicate(true)
 for key in L.SOCIAL_KEYS+L.FUNCTION_KEYS:rows[key]=L.convert(rows[key],key)
 var nav=N.new();nav.configure(rows)
 var room:Dictionary=world.get_room(1,1);var rid:String=room.id
 var slots:Array=old.artifact_slots(room);assert(slots.size()>=2)
 for j in [0,1]:
  var slot:Dictionary=slots[j];var p:Array=slot.xyz
  assert(world.register_physical_object("QA_ART_%d"%j,"QA artifact","RES_01",rid,true,true,false,false,true,{"viewer_category":"artifacts","home_anchor":[p[0],p[2]],"home_support_id":slot.id}))
 var actor:Dictionary=world.residents["RES_01"];actor["room_id"]=rid
 assert(world.pickup_physical_object("QA_ART_1","RES_01"))
 var before:Dictionary=world.physical_object("QA_ART_1").duplicate(true)
 var kitchen:Dictionary=world.get_room(4,0);var cups:Array=old.cup_slots(kitchen);assert(not cups.is_empty())
 var cup:Dictionary=cups[0];var cp:Array=cup.xyz
 assert(world.register_physical_object("QA_CUP","QA cup","",kitchen.id,true,true,false,false,true,{"viewer_category":"cups","home_anchor":[cp[0],cp[2]]}))
 room["depth7"]=true;kitchen["depth7"]=true
 var result:Dictionary=M.run(world,old,nav);print(result)
 assert(result.rebased==3 and result.failed==0)
 var held:Dictionary=world.physical_object("QA_ART_1")
 assert(held.current_holder_id==before.current_holder_id and held.state=="HELD" and held.current_anchor==[] and held.home_support_id==before.home_support_id)
 var placed:Dictionary=world.physical_object("QA_ART_0")
 assert(placed.home_anchor==placed.current_anchor)
 var expected:Dictionary=nav.artifact_support(room,placed.home_support_id)
 assert(placed.current_anchor==[expected.xyz[0],expected.xyz[2]])
 assert(M.run(world,old,nav).rebased==0)
 assert(world.save_world())
 var again=W.new();again.canonical_house_seed=true;again.save_path=world.save_path;assert(again.load_or_seed())
 var reload_anchor:Array=again.physical_object("QA_ART_0").current_anchor
 print("reload ",reload_anchor," expected ",placed.current_anchor)
 assert(Vector2(reload_anchor[0],reload_anchor[1]).distance_to(Vector2(placed.current_anchor[0],placed.current_anchor[1]))<.0001)
 assert(again.physical_object("QA_ART_1").current_holder_id=="RES_01")
 assert(M.run(again,old,nav).rebased==0)
 print("DEPTH7_SUPPORT_MIGRATION_PASS rebased=3 held_preserved=true replay=true idempotent=true")
 quit(0)
