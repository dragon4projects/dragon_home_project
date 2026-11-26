extends SceneTree
func _initialize()->void:call_deferred("run")
func _check(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func _home(scene,id:String,size:String,slot:Dictionary,small:bool=false)->bool:
 var meta:Dictionary={"viewer_category":"artifacts","display_mode":"cube","artifact_size":size,"home_anchor":[slot.xyz[0],slot.xyz[2]],"home_support_id":slot.id,"display_world_height":float(slot.dimensions[1]),"object_class":"small_artifact" if small else "display_object"}
 return scene.world.register_physical_object(id,"QA geometry "+id,"",scene.world.dense_artifact_world.room_id,true,true,small,small,not small,meta)
func _select(adapter,projection:Dictionary,id:String,size:String)->Dictionary:
 var candidate:Dictionary=projection.duplicate(true)
 candidate[id]={"viewer_category":"artifacts","artifact_size":size}
 for slot in adapter.choices():
  if slot.size==size and adapter.available(candidate,id,slot.id):return slot
 return {}
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_ARTIFACT_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var world=scene.world
 var adapter=world.dense_artifact_world
 if not _check(adapter!=null and world.save_path=="user://dragon_house_dense_artifact_qa_v1.json","new isolated QA mode missing"):return
 var room:Dictionary=world.room_by_id(adapter.room_id)
 var real:Array=[]
 for obj in world.objects.values():
  if str(obj.get("home_support_id","")).begins_with("DG:") and not str(obj.id).begins_with("QA_GRID_"):real.append(obj.id)
 print("ARTIFACT_WORLD real=",real," slots=",adapter.slots.size())
 if not _check(real.size()>0 and adapter.validate_projection(world.objects),"no real artifact assignments"):return
 var restart:bool=OS.get_environment("DRAGON_GRID_RESTART")=="1"
 if not restart:
  var large:Dictionary=_select(adapter,world.objects,"QA_GRID_L","L")
  if not _check(not large.is_empty() and _home(scene,"QA_GRID_L","L",large),"L event registration failed"):return
  var before:int=world.object_events.store.last_sequence()
  var overlap:Dictionary={}
  for slot in adapter.choices():
   if slot.grid_id==large.grid_id and slot.size=="S":overlap=slot;break
  if not _check(not overlap.is_empty() and not _home(scene,"QA_GRID_OVERLAP","S",overlap) and world.object_events.store.last_sequence()==before,"overlap must reject before append"):return
  var medium:Dictionary=_select(adapter,world.objects,"QA_GRID_M","M")
  if not _check(not medium.is_empty() and _home(scene,"QA_GRID_M","M",medium),"M event registration failed"):return
  var small:Dictionary=_select(adapter,world.objects,"QA_GRID_S","S")
  if not _check(not small.is_empty() and _home(scene,"QA_GRID_S","S",small,true),"S event registration failed"):return
  if not _check(not world.can_ambient_pickup_object("QA_GRID_L") and not world.can_ambient_pickup_object("QA_GRID_M") and world.can_ambient_pickup_object("QA_GRID_S"),"ambient size gate failed"):return
  before=world.object_events.store.last_sequence()
  if not _check(not world.assign_physical_object_home("QA_GRID_S",room.id,Vector2(overlap.xyz[0],overlap.xyz[2]),true,overlap.id) and world.object_events.store.last_sequence()==before,"overlap home move must reject"):return
  if not _check(not world.assign_physical_object_home("QA_GRID_S",room.id,Vector2.ZERO,true,""),"grid escape must reject"):return
  var alt:Dictionary={}
  for slot in adapter.choices():
   if slot.size=="S" and slot.id!=small.id and adapter.available(world.objects,"QA_GRID_S",slot.id):alt=slot;break
  if not _check(not alt.is_empty() and world.assign_physical_object_home("QA_GRID_S",room.id,Vector2(alt.xyz[0],alt.xyz[2]),true,alt.id),"valid rehome failed"):return
  var actor:Dictionary=world.residents["RES_01"]
  # Fixture actor starts in this authorized room; no fabricated owner content.
  actor["room_id"]=room.id
  actor["active"]=true
  if not _check(world.pickup_physical_object("QA_GRID_S","RES_01"),"pickup failed"):return
  if not _check(world.physical_object("QA_GRID_S").get("current_support_id","")=="" and world.physical_object("QA_GRID_S").home_support_id==alt.id,"home reservation not preserved while held"):return
  if not _check(world.restore_physical_object_home("QA_GRID_S"),"restore home failed"):return
  if not _check(world.physical_object("QA_GRID_S").current_support_id==alt.id,"restore lost support"):return
 else:
  for id in ["QA_GRID_L","QA_GRID_M","QA_GRID_S"]:
   if not _check(not world.physical_object(id).is_empty(),"missing replayed "+id):return
  if not _check(world.physical_object("QA_GRID_L").artifact_size=="L" and world.physical_object("QA_GRID_M").artifact_size=="M" and world.physical_object("QA_GRID_S").artifact_size=="S","size replay failed"):return
  if not _check(world.physical_object("QA_GRID_OVERLAP").is_empty(),"rejected object replayed"):return
 if not _check(adapter.validate_projection(world.objects),"invalid projection"):return
 scene.make_physical_objects()
 await process_frame
 scene.selected_room=room.id
 scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod();scene.update_physical_objects()
 for id in ["QA_GRID_L","QA_GRID_M","QA_GRID_S"]:
  var obj:Dictionary=world.physical_object(id)
  var slot:Dictionary=adapter.slots[obj.current_support_id]
  var node:Node3D=scene.object_nodes[id]
  var dims:Vector3=adapter.registry.sizes[obj.artifact_size]
  var target:Vector3=world.room_center_pos(room)+Vector3(slot.xyz[0],slot.xyz[1],slot.xyz[2])
  if not _check(node.visible and node.position.distance_to(target)<.001 and node.scale.is_equal_approx(Vector3.ONE) and absf(float(node.get_meta("artifact_cube_side"))-dims.x)<.001 and absf(float(node.get_meta("artifact_cube_height"))-dims.y)<.001,"wrong rendered placement "+id):return
 if not _check(scene.dense_artifact_empty_nodes.size()>0,"missing real empty holders"):return
 var fixture_path:="user://qa_grid_image.png"
 if not restart:
  var fixture:=Image.create_empty(640,320,false,Image.FORMAT_RGBA8)
  fixture.fill(Color("#6c466c"))
  if not _check(fixture.save_png(fixture_path)==OK,"fixture write failed"):return
  var sid:String=scene.dense_artifact_empty_nodes.keys()[0]
  if not _check(scene.open_content_hotspot({"category":"dense_artifact_empty","item_id":sid}) and scene.content_viewer.artwork_assign.visible,"empty holder assignment affordance missing"):return
  scene.dense_v2_pending_frame=sid
  scene._assign_dense_v2_artwork(fixture_path)
  await process_frame
 var image_id:String="LOCAL_GRID_"+FileAccess.get_sha256(fixture_path)
 var imported:Dictionary=world.physical_object(image_id)
 if not _check(not imported.is_empty() and FileAccess.get_sha256(imported.full_image_path)==imported.artifact_source_sha256 and imported.artifact_source_sha256==FileAccess.get_sha256(fixture_path),"local master persistence failed"):return
 if not _check(scene.open_content_hotspot({"category":"artifacts","item_id":image_id}) and scene.content_viewer.preview.texture!=null and scene.content_viewer.preview.texture.get_size()==Vector2(640,320),"full-size master viewer failed"):return
 scene.content_viewer.close_viewer()
 var thumb:=Image.new()
 if not _check(thumb.load(imported.preview_path)==OK and thumb.get_width()==512,"preview derivative failed"):return
 if not _check(adapter.validate_projection(world.objects),"import caused invalid projection"):return
 print("DENSE_ARTIFACT_LOCAL_MASTER_PASS restart=",restart," original_sha_verified=true full_size=640x320")
 var nav=scene.life.candidate_navigation
 var claims:=0
 for obj in scene.life.stations.display_objects(world,room):
  if not str(obj.get("current_support_id","")).begins_with("DG:"):continue
  var claim:Dictionary=scene.life.stations.display_claim(world,world.residents["RES_01"],room,obj)
  if claim.is_empty():continue
  if not _check(not nav.path(room,Vector2(-7.12,1.5),claim.offset).is_empty() and not nav.path(room,Vector2(7.12,1.5),claim.offset).is_empty(),"display claim path failure"):return
  claims+=1
 if not _check(claims>0,"no artifact viewing claim"):return
 if not _check(world.save_world(),"save failed"):return
 print("DENSE_ARTIFACT_WORLD_PASS restart=",restart," real=",real.size()," empty=",scene.dense_artifact_empty_nodes.size()," view_claims=",claims," revision=",world.object_events.store.last_sequence())
 quit(0)
