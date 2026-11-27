extends SceneTree
const W=preload("res://scripts/world_model.gd")
class FailingWorld extends W:
 var refuse:=false
 func save_world()->bool:
  if refuse:return false
  return super.save_world()
func _initialize()->void:
 var w=FailingWorld.new()
 w.canonical_house_seed=true
 w.save_path="user://i94_room_build.json"
 w.seed_world()
 var before:Array=w.rooms.duplicate(true)
 var next:int=w.next_room_id
 assert(w.can_build_room(8,1,"common",3))
 assert(not w.can_build_room(8,1,"common",4))
 w.refuse=true
 assert(not w.build_room(8,1,"common",3))
 assert(w.rooms==before and w.next_room_id==next)
 w.refuse=false
 assert(w.build_room(8,1,"common",3))
 var added:Dictionary=w.get_room(8,1)
 assert(added["interior_variant"]=="runtime_common")
 assert(w.rooms.slice(0,before.size())==before)
 assert(w.get_room(10,1)["id"]==added["id"])
 var restore=W.new()
 restore.canonical_house_seed=true
 restore.save_path=w.save_path
 assert(restore.load_or_seed())
 assert(restore.get_room(8,1)["id"]==added["id"])
 assert(restore.get_room(8,1)["interior_variant"]=="runtime_common")
 for original in before:
  var actual:Dictionary=restore.room_by_id(original.id)
  for key in ["id","x","level","type","size_modules","immutable_topology","owner_id"]:
   assert(actual.get(key)==original.get(key),str([original.id,key,actual.get(key),original.get(key)]))
 print("I94_ROOM_ADD_TRANSACTION_PASS rollback=true seed_immutable=true unique_hearth_variant=true reload=true")
 quit(0)
