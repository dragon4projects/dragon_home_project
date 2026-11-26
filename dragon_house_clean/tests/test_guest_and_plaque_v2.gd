extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func focus(s:Fixture,room:Dictionary)->void:
 s.selected_room=room.id
 s.set_mode("ROOM")
 s.zoom_current=s.zoom
 s.smooth_focus=s.desired_focus
 s.apply_camera(1.0)
 s.update_render_lod()
func capture(s:Fixture,label:String)->void:
 if DisplayServer.get_name()=="headless":return
 for i in range(2):
  await process_frame
  await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://"+label+".png")==OK)
 print("GUEST_PLAQUE_CAPTURE ",label," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func run()->void:
 var s=Fixture.new()
 root.add_child(s)
 current_scene=s
 var w=s.world
 var nav=s.life.candidate_navigation
 var seen:Dictionary={}
 var gain:float=INF
 var longest:Dictionary={}
 for profile in w.read_resident_profiles():
  var room:Dictionary=w.room_by_id(w.residents[profile.id].home_room_id)
  var node:Node3D=s.room_root.get_node(str(room.id))
  var label:Label3D=node.get_node("DoorWallName")
  var plaque:MeshInstance3D=node.get_node("DoorNamePlaque")
  var full_name:String=str(label.get_meta("public_full_name"))
  assert(full_name==str(profile.display_name) and not seen.has(full_name))
  assert(label.text.replace("\n"," ")==full_name)
  seen[full_name]=true
  var font:Font=label.font if label.font!=null else ThemeDB.fallback_font
  var lines:PackedStringArray=label.text.split("\n")
  var metrics:=Vector2(0.0,font.get_height(label.font_size)*lines.size())
  for line in lines:metrics.x=maxf(metrics.x,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x)
  var size:Vector3=plaque.mesh.size
  assert((metrics.x+10.0)*label.pixel_size<=size.x and (metrics.y+10.0)*label.pixel_size<=size.y)
  var old_size:float=24.0*minf(0.0037,1.18/(24.0*maxf(1.0,float(full_name.length())*0.65)))
  gain=minf(gain,label.font_size*label.pixel_size/old_size)
  if longest.is_empty() or str(profile.display_name).length()>str(longest.display_name).length():longest=profile
  assert(node.get_node_or_null("LocalFurniture")==null)
  focus(s,room)
  var point:Vector2=s.camera.unproject_position(plaque.global_position)
  assert(s._door_plaque_at_screen(point)==room.id)
  s.update_content_hover(point)
  assert(s.content_hover_label.visible and s.content_hover_label.text==full_name)
  var paper:Node3D=s.door_note_anchors[room.id]
  assert(s.door_note_at_screen(s.camera.unproject_position(paper.global_position))==room.id)
 assert(seen.size()==24)
 print("PLAQUE_METRICS owners=24 min_glyph_scale_gain=",gain)
 var longest_room:Dictionary=w.room_by_id(w.residents[longest.id].home_room_id)
 focus(s,longest_room)
 var long_node:Node3D=s.room_root.get_node(str(longest_room.id))
 var long_label:Label3D=long_node.get_node("DoorWallName")
 var plaque:MeshInstance3D=long_node.get_node("DoorNamePlaque")
 s.content_hover_label.visible=false
 var old_size:float=long_label.pixel_size
 var new_text:String=long_label.text
 long_label.text=str(long_label.get_meta("public_full_name"))
 long_label.font_size=24
 long_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 long_label.pixel_size=minf(0.0037,1.18/(24.0*maxf(1.0,float(long_label.text.length())*0.65)))
 long_label.position.y=2.25
 plaque.mesh=BoxMesh.new()
 plaque.mesh.size=Vector3(1.18,0.34,0.055)
 plaque.position.y=2.25
 await capture(s,"long_plaque_before")
 long_label.font_size=48
 long_label.text=new_text
 long_label.pixel_size=old_size
 long_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 long_label.position.y=2.35
 plaque.mesh.size=Vector3(1.24,0.60,0.055)
 plaque.position.y=2.35
 await capture(s,"long_plaque_after")
 s.update_content_hover(s.camera.unproject_position(plaque.global_position))
 await capture(s,"long_plaque_hover")
 s.content_hover_label.visible=false
 s.update_hud()
 assert(s.hud_status.text.contains(str(longest.display_name)))
 for id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
  var room:Dictionary=w.guest_room_for(id)
  var key:String=nav.key(room)
  var hw:float=2.4*float(room.size_modules)
  assert(nav.segment_clear(room,Vector2(-hw+0.08,1.5),Vector2(hw-0.08,1.5)))
  assert(w.set_guest_room_open(room.id,true))
  focus(s,room)
  var node:Node3D=s.room_root.get_node(str(room.id))
  var rig:Node3D=node.get_node("LocalFurniture/CanonicalInteriorLightRig")
  assert(rig.get_child_count()==2)
  if id=="NPC_CENTAUR":
   assert(room.size_modules==2)
   var row:Dictionary=nav.layouts[key]
   assert(row.guest_composition_revision=="CENTAUR_COMPOSITION_V2")
   var mat:Dictionary=row.instances.filter(func(i):return i.instance_id=="guest_centaur_01_rest_mat")[0]
   assert(float(mat.bounds_max_m[0])-float(mat.bounds_min_m[0])>2.4)
   assert(mat.station_candidates.size()==1)
   var contact:Dictionary=mat.station_candidates[0]
   assert(contact.kind=="floor_rest" and contact.room_local_xyz==[mat.room_local_xyz[0],mat.bounds_max_m[1],mat.room_local_xyz[2]])
   var matched:Array=nav.candidate_spots(room).filter(func(spot):return spot.id==contact.station_candidate_id)
   assert(matched.size()==1 and matched[0].kind=="floor_rest")
  for spot in nav.candidate_spots(room):
   for entry in [Vector2(-hw+0.08,1.5),Vector2(hw-0.08,1.5)]:
    assert(not nav.path(room,entry,spot.offset).is_empty())
  await capture(s,key.replace("/","_")+"_open")
  assert(w.set_guest_room_open(room.id,false))
  s.update_render_lod()
  node=s.room_root.get_node(str(room.id))
  assert(node.get_node_or_null("LocalFurniture")==null and node.get_node_or_null("Layer_OverviewCues")==null)
  assert(not is_instance_valid(rig) and not s.detailed_room_groups.has(room.id))
  assert(not w.public_cutaway_allowed(room))
  await capture(s,key.replace("/","_")+"_closed")
  assert(w.set_guest_room_open(room.id,true))
  s.update_render_lod()
  node=s.room_root.get_node(str(room.id))
  assert(node.get_node_or_null("LocalFurniture/CanonicalInteriorLightRig")!=null)
 print("GUEST_PLAQUE_V2_PASS names=24 hover=24 notes=24 guests=3 closure_reopen=true")
 quit(0)
