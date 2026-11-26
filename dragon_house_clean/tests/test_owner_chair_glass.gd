extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=Fixture.new();root.add_child(s);current_scene=s
 var w=s.world
 var nav=s.life.candidate_navigation
 var bank=s.teea008_review
 var chairs:=0
 var compatible:=0
 var glasses:=0
 for room in w.matching_rooms(["rest","music","artifact","workshop"]):
  var key:String=nav.key(room)
  var row:Dictionary=bank.layouts[key]
  assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
  var items:Array=row.instances
  var fixed:Array=items.filter(func(i):return i.placement_policy=="floor_fixed")
  for i in range(fixed.size()):
   for j in range(i+1,fixed.size()):
    var a:Dictionary=fixed[i];var b:Dictionary=fixed[j]
    assert(minf(a.bounds_max_m[0],b.bounds_max_m[0])-maxf(a.bounds_min_m[0],b.bounds_min_m[0])<=.001 or minf(a.bounds_max_m[2],b.bounds_max_m[2])-maxf(a.bounds_min_m[2],b.bounds_min_m[2])<=.001,str([key,a.instance_id,b.instance_id]))
  for a in w.residents.values():
   a.active=false
   s.life.stations.release(a)
  for a in w.creatures.values():a.active=false
  var spot_list:Array=nav.candidate_spots(room).filter(func(p):return p.get("candidate_asset_id","")=="blendkit_sofa_set_chair")
  if key in ["rest_social_upper/R3","rest_social_lower/R3","music/R3"]:
   assert(spot_list.size()==1,str([key,spot_list]))
   var spot:Dictionary=spot_list[0]
   for entry in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:assert(not nav.path(room,entry,spot.offset).is_empty())
   var intent:String="LISTEN_MUSIC" if key=="music/R3" else "REST"
   var chosen:Dictionary={}
   var n:=0
   for i in range(1,25):
    var a:Dictionary=w.residents["RES_%02d"%i]
    if not nav.pose_contact(a,spot,intent).is_empty():
     n+=1
     if chosen.is_empty():chosen=a
   assert(n>=20,str([key,n]))
   assert(not chosen.is_empty())
   var claim:Dictionary=s.life.stations._candidate_claim(chosen,room,0,spot,intent)
   assert(claim.has("contact"))
   s.life.stations.commit_claim(chosen,claim)
   var p:Vector3=w.room_local_to_world(room,claim.offset)
   chosen.merge({"active":true,"room_id":room.id,"level":room.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":intent},true)
   chairs+=1
   compatible+=n
   print("CHAIR ",key," compatible=",n," actor=",chosen.id)
  for item in items:
   if item.instance_id not in ["owner_lab_beaker","owner_gallery_glass_cover"]:continue
   var host_id:String=bank._support_host_id(item)
   var host:Dictionary=items.filter(func(i):return i.instance_id==host_id)[0]
   assert(absf(item.bounds_min_m[1]-host.bounds_max_m[1])<.001)
   assert(item.bounds_min_m[0]>=host.bounds_min_m[0] and item.bounds_max_m[0]<=host.bounds_max_m[0] and item.bounds_min_m[2]>=host.bounds_min_m[2] and item.bounds_max_m[2]<=host.bounds_max_m[2])
   glasses+=1
  s.selected_room=room.id;s.set_mode("ROOM");s.zoom=19.0;s.zoom_current=s.zoom;s.smooth_focus=s.desired_focus;s.yaw=0.0;s.apply_camera(1.0);s.update_render_lod();s.update_residents();s.update_physical_objects()
  for a in w.residents.values():
   if a.active:
    assert(s._active_station_render_contact(a).get("state","")=="RELAXED_SIT")
    assert(s.actor_animations[a.id].state=="RELAXED_SIT")
  if DisplayServer.get_name()!="headless":
   for i in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("user://iter49_"+key.replace("/","_")+".png")==OK)
 assert(chairs==3 and glasses==2,str([chairs,glasses]))
 print("OWNER_CHAIR_GLASS_PASS chairs=",chairs," compatible_profiles=",compatible," supported_glass=",glasses)
 quit()
