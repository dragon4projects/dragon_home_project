extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/canonical_lift_capacity.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path="user://lift_fifo.json"
 assert(w.load_or_seed())
 for a in w.residents.values():a.active=false
 for a in w.creatures.values():a.active=false
 var l=L.new()
 l.setup(w)
 var room:Dictionary=w.get_room(0,0)
 var start:Vector3=w.room_center_pos(room)
 var end:Vector3=w.room_center_pos(w.get_room(0,1))
 var ids:Array=[]
 for i in range(9):
  var id:String="RES_%02d"%(i+1)
  ids.append(id)
  var a:Dictionary=w.residents[id]
  a.merge({"active":true,"phase":"travel","room_id":room.id,"level":0,"x":start.x,"visual_y":start.y,"z":0.0,"waypoint_index":0,"waypoints":[{"kind":"lift","room_id":w.get_room(0,1).id,"position":[end.x,end.y,end.z]}]},true)
  if i<6:assert(not l.target(a,start,end).get("wait",false))
  elif i<8:assert(l.target(a,start,end).get("wait",false))
 assert(l.queues["0"].size()==2)
 assert(w.save_world())
 var r=W.new()
 r.canonical_house_seed=true
 r.save_path=w.save_path
 assert(r.load_or_seed())
 l=L.new()
 l.setup(r)
 assert(l._first_waiter("0")==ids[6])
 var a:Dictionary=r.residents[ids[0]]
 l.release(a)
 a.phase="idle"
 # Later waiter is deliberately stepped first; newcomer also cannot jump.
 assert(l.target(r.residents[ids[7]],start,end).get("wait",false))
 assert(l.target(r.residents[ids[8]],start,end).get("wait",false))
 assert(not l.target(r.residents[ids[6]],start,end).get("wait",false))
 assert(l._first_waiter("0")==ids[7])
 # Cancellation removes the queue ticket at the next authoritative sync.
 r.residents[ids[7]]["autonomy_enabled"]=false
 l.sync()
 assert(l._first_waiter("0")==ids[8])
 assert(not r.residents[ids[7]].has("canonical_lift_wait"))
 l.release(r.residents[ids[1]])
 r.residents[ids[1]].phase="idle"
 assert(not l.target(r.residents[ids[8]],start,end).get("wait",false))
 assert(l.queues.is_empty() and l.occupied["0"].size()==6)
 # Re-enabled cancelled actor rejoins at the tail, never keeps its old ticket.
 r.residents[ids[7]]["autonomy_enabled"]=true
 assert(l.target(r.residents[ids[7]],start,end).get("wait",false))
 assert(int(r.residents[ids[7]].canonical_lift_wait.serial)>2)
 r.residents[ids[7]].phase="idle"
 l.sync()
 assert(l.queues.is_empty())
 print("LIFT_FIFO_PASS saved_queue=true no_barging=true cancellation=true capacity=6")
 quit(0)
