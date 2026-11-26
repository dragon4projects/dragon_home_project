extends SceneTree
const D=preload("res://scripts/depth7_space.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 for i in range(1,8):
  print("DEPTH_BAND ",i," z=",D.center(i)," scale=",D.scale_at(D.center(i)))
  assert(D.band(D.center(i))==i)
  assert(D.passage(D.center(i))==(i in [1,3,5]))
 assert(is_equal_approx(D.scale_at(D.center(1)),1.0))
 assert(is_equal_approx(D.scale_at(D.center(7)),.60))
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 scene.set_process(false)
 await process_frame
 assert(scene.architecture_review and scene.teea008_live)
 var room:Dictionary=scene.world.get_room(-3,1)
 assert(D.enabled_for(room))
 assert(scene.world.room_contains_local(room,Vector2(0,-7.4)))
 assert(not scene.world.room_contains_local(room,Vector2(0,-8.2)))
 var group:Node3D=scene.room_root.get_node(str(room["id"]))
 assert(group.find_child("Depth7Hearth",true,false)!=null)
 assert(group.find_children("HEARTH_PICTURE_*","MeshInstance3D",true,false).size()==10)
 var nav=scene.life.candidate_navigation
 var row:Dictionary=nav.layouts["common/R3"]
 var spots:Array=nav.candidate_spots(room)
 var seats:=0
 for spot in spots:
  if str(spot.get("candidate_kind",""))!="seat":continue
  seats+=1
  for x in [-7.12,7.12]:
   var path:Array=nav.path(room,Vector2(x,1.5),spot.offset)
   assert(not path.is_empty(),str([spot.id,x]))
   var previous:=Vector2(x,1.5)
   for point in path:
    assert(nav.segment_clear(room,previous,point))
    previous=point
 assert(seats==19,str(seats))
 for i in [1,3,5]:
  assert(nav.segment_clear(room,Vector2(-7.12,D.center(i)),Vector2(7.12,D.center(i))),str(i))
 assert(not nav.clear(room,Vector2(5.0,-5.5)))
 assert(scene.room_root.get_child_count()==65)
 var social_count:=0
 var L=load("res://scripts/depth7_layout.gd")
 for r in scene.world.rooms:
  if not nav.key(r) in L.SOCIAL_KEYS:continue
  assert(D.enabled_for(r),str(r))
  var node:Node3D=scene.room_root.get_node(str(r["id"]))
  assert(node.get_node_or_null("Layer_Structure/CutawayFloorSlab")!=null)
  assert(is_equal_approx(node.get_node("Layer_Structure/CutawayFloorSlab").mesh.size.z,9.7))
  assert(node.get_node("Layer_OverviewCues").get_meta("real_model_count",0)>0)
  for i in [1,3,5]:assert(nav.segment_clear(r,Vector2(-7.12,D.center(i)),Vector2(7.12,D.center(i))))
  assert(nav.cup_slots(r).size()>=2)
  social_count+=1
 assert(social_count==3,str(social_count))
 var functional_count:=0
 for r in scene.world.rooms:
  var key:String=nav.key(r)
  if not key in L.FUNCTION_KEYS:continue
  assert(D.enabled_for(r),key)
  var node:Node3D=scene.room_root.get_node(str(r["id"]))
  assert(is_equal_approx(node.get_node("Layer_Structure/CutawayFloorSlab").mesh.size.z,9.7))
  scene.selected_room=r["id"]
  scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
  var layer:Node3D=node.get_node("LocalFurniture")
  assert(scene.detailed_room_groups.has(str(r["id"])),key)
  var expected:=0
  for sid in scene.teea008_review.surfaces:
   if scene.teea008_review.surfaces[sid].room_variant==key:expected+=1
  assert(layer.find_children("Aperture_*","Node3D",true,false).size()==expected,key)
  if key=="library/R3":assert(nav.book_slots(r).size()==10)
  if key=="artifact/R3":assert(nav.artifact_slots(r).size()==28)
  if DisplayServer.get_name()!="headless":
   for i in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter63_"+str(r["id"])+"_"+key.get_slice("/",0)+".png")==OK)
  functional_count+=1
 assert(functional_count==8,str(functional_count))
 print("DEPTH7_FUNCTION_RUNTIME_PASS rooms=",functional_count)
 # Canonical traffic must not avoid or reserve positions of other walkers.
 var Traffic=load("res://scripts/teea008_traffic.gd")
 var traffic=Traffic.new()
 traffic.begin(scene.world,nav)
 var c:Vector3=scene.world.room_center_pos(room)
 var a:=Vector3(c.x-1,c.y,D.center(5));var b:=Vector3(c.x+1,c.y,D.center(5))
 var actor={"id":"QA_WALKER_A","room_id":room["id"]}
 traffic.positions["QA_WALKER_B"]=b
 assert(traffic.step(actor,a,b,b,2.0,"candidate_path")==b)
 traffic.finish()
 print("DEPTH7_SOCIAL_RUNTIME_PASS rooms=",social_count," overlap_pass=true")
 scene.selected_room=room["id"]
 scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 if DisplayServer.get_name()!="headless":
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter61_runtime.png")==OK)
 print("DEPTH7_RUNTIME_PASS rooms=65 seats=",seats," routes=",seats*2," passage_lanes=3 frames=10")
 quit(0)
