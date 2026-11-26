extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func focus(s:Fixture,room:Dictionary,actor:Dictionary)->void:
 s.selected_room=room.id
 s.set_mode("ROOM")
 s.zoom=6.0
 s.zoom_current=6.0
 s.desired_focus=s.world.room_center_pos(room)+Vector3(float(actor.x)-s.world.room_center_pos(room).x,1.0,float(actor.z))
 s.smooth_focus=s.desired_focus
func capture(s:Fixture,label:String)->void:
 if DisplayServer.get_name()=="headless":return
 for i in range(2):
  await process_frame
  await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://"+label+".png")==OK)
 print("RES07_CAPTURE ",label)
func run()->void:
 var s=Fixture.new()
 root.add_child(s)
 current_scene=s
 var w=s.world
 var a:Dictionary=w.residents.RES_07
 assert(a.runtime_visual_bound and a.visual_wardrobe=="HOME")
 var nav=s.life.candidate_navigation
 for id in w.residents:
  if id!="RES_07":w.residents[id].active=false
 for creature in w.creatures.values():creature.active=false
 var cinema:Dictionary=w.matching_rooms(["cinema"])[0]
 var claim:Dictionary=s.life.stations.single(w,a,cinema,"WATCH_FILM")
 assert(claim.get("contact",{}).get("state","")=="SIT_E_OCCLUDED")
 s.life.stations.commit_claim(a,claim)
 var c:Vector3=w.room_local_to_world(cinema,claim.offset)
 a.merge({"active":true,"room_id":cinema.id,"level":cinema.level,"x":c.x,"visual_y":c.y,"z":c.z,"phase":"perform","intent":"WATCH_FILM"},true)
 focus(s,cinema,a)
 s.yaw=0.0
 s.apply_camera(1.0)
 s.update_render_lod()
 s.update_residents()
 assert(s.actor_animations[a.id].state=="SIT_E_OCCLUDED")
 var sprite:Sprite3D=s.actor_sprites[a.id].get_node("Body")
 assert(sprite.texture==s._side_seated_texture(a,nav.pose_profile(a,"SIT_E_OCCLUDED")))
 assert(s._active_station_render_contact(a).state=="SIT_E_OCCLUDED")
 for id in s.actor_sprites:
  if id!=a.id:assert(not s.actor_sprites[id].visible)
 await capture(s,"res07_cinema_side_seated")
 # Real cup from the canonical world, not a prop duplicated in the sprite.
 var kitchen:Dictionary=w.matching_rooms(["kitchen"])[0]
 var cup_id:String=""
 var slot:Dictionary={}
 for id in w.objects:
  var o:Dictionary=w.objects[id]
  if str(o.get("viewer_category",""))!="cups" or o.current_room_id!=kitchen.id or o.current_holder_id!="":continue
  slot=s.life.candidate_cups.slot_for_object(o)
  if not slot.is_empty():
   cup_id=id
   break
 assert(cup_id!="")
 s.life.stations.release(a)
 c=w.room_local_to_world(kitchen,slot.approach)
 a.merge({"room_id":kitchen.id,"level":kitchen.level,"x":c.x,"visual_y":c.y,"z":c.z,"phase":"perform","intent":"GET_COFFEE"},true)
 assert(w.pickup_physical_object(cup_id,a.id))
 focus(s,kitchen,a)
 var truth:Dictionary=w.objects[cup_id].duplicate(true)
 var coords:Array=[a.x,a.visual_y,a.z]
 for yaw in [-0.42,0.0,0.42]:
  s.yaw=yaw
  s.apply_camera(1.0)
  s.update_render_lod()
  s.update_residents()
  s.update_physical_objects()
  var anchor:Node3D=s.object_nodes[cup_id]
  assert(anchor.visible and anchor.get_meta("hand_contact_status")=="IDLE_FRAME_MARKED")
  var marker:Node3D=anchor.find_child("PICKUP_ANCHOR",true,false)
  assert(marker!=null and marker.global_position.distance_to(anchor.get_meta("hand_contact_target"))<0.0001)
  assert(s.actor_animations[a.id].state=="IDLE_S")
  assert(sprite.texture==s.asset_banks.texture_for(a.id,"HOME","IDLE_S",0))
  assert(w.objects[cup_id]==truth and coords==[a.x,a.visual_y,a.z])
  await capture(s,"res07_cup_"+str(roundi(yaw*100)))
 # Hiding the carrier must not mutate ownership, or leave a floating cup.
 a.active=false
 s.update_residents()
 s.update_physical_objects()
 assert(not s.actor_sprites[a.id].visible and not s.object_nodes[cup_id].visible)
 assert(w.objects[cup_id]==truth)
 a.active=true
 s.update_residents()
 s.update_physical_objects()
 assert(s.actor_sprites[a.id].visible and s.object_nodes[cup_id].visible)
 a.phase="travel"
 a.moving_axis="left"
 s.update_residents()
 s.update_physical_objects()
 assert(s.object_nodes[cup_id].get_meta("hand_contact_status")=="UNCALIBRATED_MOVING_OR_NONMODEL")
 print("CANONICAL_RES07_VISUAL_PASS side_seated=true hand_yaw_samples=3 world_truth_unchanged=true unverified_walk_denied=true")
 quit(0)
