extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func capture(scene:Fixture,label:String)->void:
 if DisplayServer.get_name()=="headless":return
 for i in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://"+label+".png")==OK)
 print("SOCIAL_CAPTURE ",label," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func run()->void:
 var scene=Fixture.new()
 root.add_child(scene)
 current_scene=scene
 assert(scene.architecture_review and scene.teea008_live)
 var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/canonical_social_interiors_20261125.json"))
 var original:Dictionary={}
 for row in raw.variants:original[row.variant_id]=row
 var nav=scene.life.candidate_navigation
 var w=scene.world
 var clock:float=w.sim_clock
 var actors:Dictionary=w.residents.duplicate(true)
 var objects:Dictionary=w.objects.duplicate(true)
 for room in w.matching_rooms(["kitchen","rest"]):
  var key:String=nav.key(room)
  var current:Dictionary=scene.teea008_review.layouts[key]
  scene.selected_room=room.id
  scene.set_mode("ROOM")
  scene.zoom_current=scene.zoom
  scene.smooth_focus=scene.desired_focus
  scene.apply_camera(1.0)
  scene.update_render_lod()
  var node:Node3D=scene.room_root.get_node(NodePath(str(room.id)))
  assert(scene.detailed_room_groups.has(room.id))
  scene._release_furniture(node)
  scene.teea008_review.layouts[key]=original[key]
  scene.update_render_lod()
  scene.update_residents()
  scene.update_physical_objects()
  await capture(scene,key.replace("/","_")+"_before")
  scene._release_furniture(node)
  scene.teea008_review.layouts[key]=current
  scene.update_render_lod()
  scene.update_residents()
  scene.update_physical_objects()
  await capture(scene,key.replace("/","_")+"_after")
  scene.set_mode("HOUSE")
 assert(w.sim_clock==clock and w.residents==actors and w.objects==objects)
 print("SOCIAL_ZONES_VISUAL_PASS rooms=3 world_unchanged=true")
 quit(0)
