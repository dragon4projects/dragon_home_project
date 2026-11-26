extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=Fixture.new()
 root.add_child(s)
 current_scene=s
 var w=s.world
 var l=s.life
 var a:Dictionary=w.residents.RES_01
 for other in w.residents.values():other.active=false
 for creature in w.creatures.values():creature.active=false
 var start:Dictionary=w.get_room(0,-2)
 var target:Dictionary=w.matching_rooms(["library"])[0]
 var c:Vector3=w.room_center_pos(start)
 a.merge({"active":true,"autonomy_enabled":true,"room_id":start.id,"level":start.level,"x":c.x,"visual_y":c.y,"z":0.0,"phase":"idle","intent":"PURPOSEFUL_EXPLORE","until":0.0,"waypoint_index":0,"waypoints":[]},true)
 l.stations.release(a)
 var route:Array=w.find_route(start.id,target.id,a.id)
 var claim:Dictionary=l.stations.single(w,a,target,"PURPOSEFUL_EXPLORE")
 assert(not claim.is_empty())
 l.stations.commit_claim(a,claim)
 a.waypoints=l.locomotion.build_waypoints(w,a,route,"PURPOSEFUL_EXPLORE",claim.offset)
 assert(not a.waypoints.is_empty())
 a.phase="travel"
 s.follow_actor(a.id)
 s.zoom_current=s.zoom
 var levels:Dictionary={}
 var rooms:Dictionary={}
 var changes:=0
 var last:Dictionary={}
 var mounts:int=s.detail_materialization_count
 var evicts:int=s.detail_eviction_count
 var max_draws:=0
 var samples:=0
 for i in range(1200):
  l.canonical_lifts.sync()
  l._move(a,0.125)
  var actor_copy:Dictionary=a.duplicate(true)
  s.apply_camera(0.125)
  if i%5==0:
   s.update_render_lod()
   s.update_residents()
   assert(s.detailed_room_groups.size()<=2)
   for key in s.detailed_room_groups:
    assert(w.public_cutaway_allowed(w.room_by_id(str(key))))
   for n in s.room_root.get_children():assert(n.visible)
   if s.detailed_room_groups!=last:
    changes+=1
    last=s.detailed_room_groups.duplicate()
   samples+=1
  assert(a==actor_copy)
  assert(s.semantic_view.active_room==str(a.room_id) and s.semantic_view.level==int(a.level))
  levels[a.level]=true
  rooms[a.room_id]=true
  if DisplayServer.get_name()!="headless" and i%12==0:
   await process_frame
   await RenderingServer.frame_post_draw
   max_draws=maxi(max_draws,int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
  if a.phase!="travel":break
 assert(a.room_id==target.id and a.phase=="perform")
 assert(levels.size()>=2 and rooms.size()>=3 and samples>10)
 if DisplayServer.get_name()!="headless":
  await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("user://iter41_follow_arrival.png")==OK)
 print("MOVING_FOLLOW_PASS rooms=",rooms.size()," levels=",levels.size()," samples=",samples," budget_changes=",changes," mounts=",s.detail_materialization_count-mounts," evictions=",s.detail_eviction_count-evicts," sampled_peak_draws=",max_draws," all_shells=true world_unchanged=true")
 quit(0)
