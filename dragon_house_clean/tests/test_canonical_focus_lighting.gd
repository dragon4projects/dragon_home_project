extends SceneTree
# Full scene, same camera and world for the legacy two-room budget vs focused
# one-room detail. Optional real-render A/B capture with --audio-driver Dummy.
class Fixture extends "res://scripts/main.gd":
 var legacy_budget:=false
 var show_lighting:=true
 func _process(_delta:float)->void:pass
 func _add_canonical_interior_lighting(parent:Node3D,group:Dictionary)->void:
  if show_lighting:super._add_canonical_interior_lighting(parent,group)
 func _canonical_detail_budget()->Dictionary:
  if not legacy_budget:return super._canonical_detail_budget()
  var candidates:Array=[]
  for node in room_root.get_children():
   var group:Dictionary=visual_room_groups.get(node.name,{})
   if group.is_empty() or node.get_node_or_null("LocalFurniture")==null or _group_facade_only(group) or not semantic_view.group_visible(group):continue
   if not _is_near_detail(node):continue
   var half_width:float=float(group.get("width",1))*W*0.5
   var dx:float=maxf(0.0,absf(node.position.x-smooth_focus.x)-half_width)
   var dy:float=absf(node.position.y+1.45-smooth_focus.y)
   var score:float=dx+dy*2.0+absf(node.position.x-smooth_focus.x)*0.03
   if detailed_room_groups.has(node.name):score-=0.20
   candidates.append({"id":str(node.name),"score":score})
  candidates.sort_custom(func(a,b):return str(a.id)<str(b.id) if is_equal_approx(float(a.score),float(b.score)) else float(a.score)<float(b.score))
  var chosen:Dictionary={}
  for i in range(mini(2,candidates.size())):chosen[candidates[i].id]=true
  return chosen
func _initialize()->void:call_deferred("run")
func capture(scene:Fixture,label:String)->void:
 if DisplayServer.get_name()=="headless":return
 for i in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
 var img:Image=root.get_texture().get_image()
 assert(img.save_png("user://"+label+".png")==OK)
 print("FOCUS_CAPTURE ",label," detail=",scene.detailed_room_groups.size()," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func focus(scene:Fixture,room:Dictionary)->void:
 scene.selected_room=room.id
 scene.set_mode("ROOM")
 scene.zoom_current=scene.zoom
 scene.smooth_focus=scene.desired_focus
 scene.apply_camera(1.0)
 scene.update_render_lod()
 scene._update_physical_books()
 scene.update_residents()
func run()->void:
 var scene=Fixture.new()
 root.add_child(scene)
 current_scene=scene
 assert(scene.architecture_review and scene.teea008_live)
 var w=scene.world
 var before:Dictionary=w.residents.duplicate(true)
 var media_before:Dictionary=w.media.duplicate(true)
 var clock:float=w.sim_clock
 for spec in [["library",w.matching_rooms(["library"])[0]],["kitchen",w.matching_rooms(["kitchen"])[0]],["cinema",w.matching_rooms(["cinema"])[0]]]:
  var room:Dictionary=spec[1]
  scene.set_mode("HOUSE")
  scene.legacy_budget=true
  scene.show_lighting=false
  scene.teea008_review.compact_encyclopedia_enabled=false
  focus(scene,room)
  await capture(scene,str(spec[0])+"_before")
  scene.set_mode("HOUSE")
  scene.legacy_budget=false
  scene.show_lighting=true
  scene.teea008_review.compact_encyclopedia_enabled=true
  focus(scene,room)
  assert(scene.detailed_room_groups.size()==1 and scene.detailed_room_groups.has(room.id))
  var node:Node3D=scene.room_root.get_node(NodePath(str(room.id)))
  var lights:Node3D=node.get_node("LocalFurniture/CanonicalInteriorLightRig")
  assert(lights.get_child_count()==2)
  for light in lights.get_children():
   assert(light is OmniLight3D and not light.shadow_enabled and light.omni_range<=4.0)
  for group in scene.room_root.get_children():assert(group.visible)
  var created:int=scene.detail_materialization_count
  scene.update_render_lod()
  assert(scene.detail_materialization_count==created)
  await capture(scene,str(spec[0])+"_after")
  if spec[0]=="library":
   var wrappers:Array=[]
   for item in node.get_node("LocalFurniture").find_children("*","Node3D",true,false):
    if str(item.get_meta("candidate_asset_id",""))=="book_encyclopedia_set_01":
     var mesh:MeshInstance3D=item.get_node_or_null("CompactEncyclopedia")
     assert(mesh!=null and mesh.mesh.get_surface_count()==3)
     wrappers.append([item.name,item.visible,item.transform])
   var expected_sets:int=0
   for row in scene.teea008_review.variant("library",3).get("instances",[]):
    if row.asset_id=="book_encyclopedia_set_01":expected_sets+=1
   print("ENCYCLOPEDIA_WRAPPERS actual=",wrappers.size()," expected=",expected_sets)
   assert(expected_sets>0 and wrappers.size()==expected_sets)
   # Compare original and compact models at the same light and camera.
   scene._release_furniture(node)
   scene.teea008_review.compact_encyclopedia_enabled=false
   scene.update_render_lod()
   scene._update_physical_books()
   var original:Array=[]
   for item in node.get_node("LocalFurniture").find_children("*","Node3D",true,false):
    if str(item.get_meta("candidate_asset_id",""))=="book_encyclopedia_set_01":original.append([item.name,item.visible,item.transform])
   assert(original==wrappers)
   await capture(scene,"library_original_same_lighting")
   scene._release_furniture(node)
   scene.teea008_review.compact_encyclopedia_enabled=true
   scene.update_render_lod()
   scene._update_physical_books()
   lights=node.get_node("LocalFurniture/CanonicalInteriorLightRig")
   await capture(scene,"library_compact_same_lighting")
  scene.set_mode("HOUSE")
  assert(scene.detailed_room_groups.is_empty() and not is_instance_valid(lights))
 # Free inspection still gets the original two-room upper bound.
 scene.current_mode="FREE"
 scene.zoom_current=12.0
 scene.smooth_focus=w.room_center_pos(w.matching_rooms(["library"])[0])+Vector3.UP*1.45
 scene.update_render_lod()
 assert(scene.detailed_room_groups.size()<=2 and not scene.detailed_room_groups.is_empty())
 var private:Dictionary=w.room_by_id(str(w.residents.RES_01.home_room_id))
 focus(scene,private)
 assert(scene.detailed_room_groups.is_empty())
 assert(w.residents==before and w.media==media_before and w.sim_clock==clock)
 print("CANONICAL_FOCUS_LIGHTING_PASS selected=1 free_max=2 house=0 private=0 shadowless=true world_unchanged=true")
 quit(0)
