extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=Fixture.new();root.add_child(s);current_scene=s
 var w=s.world;var nav=s.life.candidate_navigation
 var count:=0
 for room in w.matching_rooms(["rest"]):
  var key:String=nav.key(room)
  if key not in ["rest_social_upper/R3","rest_social_lower/R3"]:continue
  var row:Dictionary=nav.layouts[key]
  assert(row.owner_sofa_revision=="OWNER_SOFA_V1")
  var spots:Array=nav.candidate_spots(room).filter(func(p):return p.get("candidate_asset_id","")=="blendkit_sofa_repaired")
  assert(spots.size()==2)
  assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
  for spot in spots:
   for x in [-7.12,7.12]:assert(not nav.path(room,Vector2(x,1.5),spot.offset).is_empty(),str([key,spot.id,x]))
   for i in range(1,25):
    assert(nav.pose_contact(w.residents["RES_%02d"%i],spot,"REST").get("state","")=="RELAXED_SIT")
    count+=1
  for a in w.residents.values():
   a.active=false;s.life.stations.release(a)
  for a in w.creatures.values():a.active=false
  for i in range(2):
   var a:Dictionary=w.residents[["RES_01","RES_07"][i]]
   var claim:Dictionary=s.life.stations._candidate_claim(a,room,i,spots[i],"REST")
   assert(claim.has("contact"))
   s.life.stations.commit_claim(a,claim)
   var p:Vector3=w.room_local_to_world(room,claim.offset)
   a.merge({"active":true,"room_id":room.id,"level":room.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":"REST"},true)
  s.selected_room=room.id;s.set_mode("ROOM");s.zoom_current=s.zoom;s.smooth_focus=s.desired_focus;s.apply_camera(1.0);s.update_render_lod();s.update_residents()
  for a in w.residents.values():
   if a.active:assert(s._active_station_render_contact(a).get("state","")=="RELAXED_SIT")
  if DisplayServer.get_name()!="headless":
   for i in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("user://iter52_"+key.replace("/","_")+".png")==OK)
  print("SOFA_ROOM ",key)
 assert(count==96)
 print("OWNER_SOFA_PASS seat_profiles=",count)
 quit()
