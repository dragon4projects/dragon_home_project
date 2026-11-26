extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func measure(label:String)->void:
 for i in range(2):
  await process_frame
  await RenderingServer.frame_post_draw
 print("LIBRARY_COST ",label," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
func run()->void:
 var s=Fixture.new()
 root.add_child(s)
 current_scene=s
 s.teea008_review.compact_encyclopedia_enabled=false
 var room:Dictionary=s.world.matching_rooms(["library"])[0]
 s.selected_room=room.id
 s.set_mode("ROOM")
 s.zoom_current=s.zoom
 s.smooth_focus=s.desired_focus
 s.apply_camera(1.0)
 s.update_render_lod()
 s._update_physical_books()
 s.update_residents()
 var node:Node3D=s.room_root.get_node(NodePath(str(room.id)))
 print("LIBRARY_COUNTS books=",s.book_nodes.size()," objects=",s.object_nodes.size()," rich=",s.detailed_room_groups.keys())
 await measure("baseline")
 for entry in [[s.book_root,"books"],[s.actor_root,"actors"],[s.creature_root,"creatures"],[node.get_node("LocalFurniture"),"selected_furniture"],[node.get_node("Layer_Background"),"selected_background"],[node.get_node("Layer_Structure"),"selected_structure"]]:
  var n:Node3D=entry[0]
  n.visible=false
  await measure("without_"+str(entry[1]))
  n.visible=true
 for n in s.room_root.get_children():
  if n!=node:n.visible=false
 await measure("only_selected_shell")
 for n in s.room_root.get_children():n.visible=true
 for n in s.room_root.get_children():
  var cues=n.get_node_or_null("Layer_OverviewCues")
  if cues!=null:cues.visible=false
 await measure("without_overview_cues")
 print("LIBRARY_COST_PROFILE_PASS")
 quit(0)
