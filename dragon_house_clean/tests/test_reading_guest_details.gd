extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=Fixture.new()
 root.add_child(s);current_scene=s
 var w=s.world;var nav=s.life.candidate_navigation
 var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/canonical_reading_guest_details_20261126.json"))
 var count:=0;var checks:=0
 for room in w.matching_rooms(["library","study","guest"]):
  var key:String=nav.key(room)
  if not spec.additions.has(key):continue
  var row:Dictionary=nav.layouts[key]
  var hw:float=float(room.size_modules)*2.4
  assert(nav.segment_clear(room,Vector2(-hw+.08,1.5),Vector2(hw-.08,1.5)),key)
  for spot in nav.candidate_spots(room):
   for x in [-hw+.08,hw-.08]:
    assert(not nav.path(room,Vector2(x,1.5),spot.offset).is_empty(),str([key,spot.id,x]))
    checks+=1
  var items:Dictionary={}
  for item in row.instances:items[item.instance_id]=item
  for item in spec.additions[key]:
   assert(items.has(item.instance_id),str([key,item.instance_id]))
   var actual:Dictionary=items[item.instance_id]
   assert(actual.station_candidates.is_empty() and actual.support_slots.is_empty())
   assert(float(actual.bounds_min_m[0])>=-hw and float(actual.bounds_max_m[0])<=hw)
   if item.placement_policy=="supported":
    var host:Dictionary=items[item.support_host_id]
    assert(absf(actual.bounds_min_m[1]-host.bounds_max_m[1])<.001)
   # Check actual imported bounding box, not just TEEA metadata.
   var model:PackedScene=load(s.teea008_review._asset_path(item.asset_id))
   var node:Node3D=model.instantiate()
   root.add_child(node)
   var bounds:=AABB();var first:=true
   for mesh in node.find_children("*","MeshInstance3D",true,false):
    var b:AABB=mesh.global_transform*mesh.get_aabb()
    if first:bounds=b;first=false
    else:bounds=bounds.merge(b)
   var lo:Array=item.local_min_m;var hi:Array=item.local_max_m
   assert(not first and bounds.position.distance_to(Vector3(lo[0],lo[1],lo[2]))<.006 and bounds.end.distance_to(Vector3(hi[0],hi[1],hi[2]))<.006,str([item.asset_id,bounds,lo,hi]))
   node.free()
   count+=1
  s.selected_room=room.id;s.set_mode("ROOM");s.zoom_current=s.zoom;s.smooth_focus=s.desired_focus;s.apply_camera(1.0);s.update_render_lod();s.update_residents()
  for item in spec.additions[key]:
   var mounted:=false
   for node in s.find_children(item.instance_id,"Node3D",true,false):
    if node.is_visible_in_tree():mounted=true
   assert(mounted,str([key,item.instance_id,"not mounted"]))
  if DisplayServer.get_name()!="headless":
   for i in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("user://iter51_"+room.id+"_"+key.replace("/","_")+".png")==OK)
  print("READING_GUEST_CAPTURE ",key," ",room.id)
 assert(count==12,str(count))
 print("READING_GUEST_DETAILS_PASS instances=",count," route_checks=",checks)
 quit()
