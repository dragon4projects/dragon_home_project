extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=Fixture.new()
 root.add_child(s)
 current_scene=s
 var w=s.world
 var nav=s.life.candidate_navigation
 var rooms:Array=w.matching_rooms(["cinema"])
 assert(rooms.size()==2)
 var tested:=0
 for room in rooms:
  var row:Dictionary=nav.layouts["cinema/R3"]
  assert(row.theatre_revision=="OWNER_THEATRE_V1")
  var spots:Array=nav.candidate_spots(room).filter(func(p):return p.get("candidate_asset_id","")=="owner_theatre_seat_pair")
  assert(spots.size()==6,str(spots))
  assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
  for spot in spots:
   for entry in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:
    assert(not nav.path(room,entry,spot.offset).is_empty())
  for i in range(1,25):
   var actor:Dictionary=w.residents["RES_%02d"%i]
   for spot in spots:
    var contact:Dictionary=nav.pose_contact(actor,spot,"WATCH_FILM")
    assert(contact.get("state","")=="SIT_E_OCCLUDED",str(actor.id))
   tested+=1
  for actor in w.residents.values():
   actor.active=false
   s.life.stations.release(actor)
  for creature in w.creatures.values():creature.active=false
  for i in range(6):
   var actor:Dictionary=w.residents[["RES_01","RES_07","RES_12","RES_19","RES_22","RES_24"][i]]
   actor.active=true
   var claim:Dictionary=s.life.stations.single(w,actor,room,"WATCH_FILM")
   assert(claim.get("contact",{}).get("state","")=="SIT_E_OCCLUDED")
   s.life.stations.commit_claim(actor,claim)
   var pt:Vector3=w.room_local_to_world(room,claim.offset)
   actor.merge({"room_id":room.id,"level":room.level,"x":pt.x,"z":pt.z,"visual_y":pt.y,"phase":"perform","intent":"WATCH_FILM"},true)
  s.selected_room=room.id
  s.set_mode("ROOM")
  s.zoom=19.0
  s.zoom_current=s.zoom
  s.smooth_focus=s.desired_focus
  var truth:Dictionary=w.residents.duplicate(true)
  for yaw in [-0.42,0.0,0.42]:
   s.yaw=yaw
   s.apply_camera(1.0)
   s.update_render_lod()
   s.update_residents()
   for actor in w.residents.values():
    if not actor.active:continue
    assert(s._active_station_render_contact(actor).state=="SIT_E_OCCLUDED")
    assert(s.actor_animations[actor.id].state=="SIT_E_OCCLUDED")
    var body:Sprite3D=s.actor_sprites[actor.id].get_node("Body")
    var im:Image=body.texture.get_image()
    var profile:Dictionary=nav.pose_profile(actor,"SIT_E_OCCLUDED")
    assert(im.get_used_rect().end.y==int(profile.alpha_bbox[3]))
   assert(w.residents==truth)
   var screen:Node3D
   for anchor in get_nodes_in_group("teea008_media_surface"):
    if anchor.get_meta("room_id","")==room.id and anchor.get_meta("surface_id","")=="cinema.r3.film.screen":screen=anchor
   assert(screen!=null)
   if yaw<=0:
    var hit:Dictionary=s.teea008_review.aperture_hit(s.camera,s.camera.unproject_position(screen.global_position))
    assert(hit.get("item_id","")=="cinema.r3.film.screen",str(hit))
   if DisplayServer.get_name()!="headless":
    for i in range(2):
     await process_frame
     await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("user://theatre_"+room.id+"_"+str(roundi(yaw*100))+".png")==OK)
   print("THEATRE_CAPTURE ",room.id," yaw=",yaw," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
 print("OWNER_THEATRE_PASS rooms=2 profiles=",tested," stations_each=6 both_entries=true")
 quit(0)
