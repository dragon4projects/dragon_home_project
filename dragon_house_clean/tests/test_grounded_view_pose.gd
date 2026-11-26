extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 scene.teea008_live=true
 scene.zoom_current=10.0
 scene.yaw=-0.18
 var w=scene.world
 var room:Dictionary=w.make_room(0,0,"artifact",3)
 var c:Vector3=w.room_center_pos(room)
 var actor:Dictionary={"id":"RES_06","active":true,"phase":"perform","intent":"VIEW_ART","room_id":room.id,"viewing_object_id":"QA_ART","x":c.x,"z":0.2}
 w.objects["QA_ART"]={"current_room_id":room.id,"current_anchor":[0.0,-1.4]}
 assert(scene.desired_actor_animation(actor)=="IDLE_N")
 w.objects.QA_ART.current_anchor=[1.0,0.2]
 assert(scene.desired_actor_animation(actor)=="IDLE_E")
 w.objects.QA_ART.current_anchor=[-1.0,0.2]
 assert(scene.desired_actor_animation(actor)=="IDLE_W")
 w.objects.QA_ART.current_room_id="ABSENT"
 assert(scene.desired_actor_animation(actor)=="IDLE_S")
 for intent in ["WATCH_FIRE","BROWSE_BOOK_CATALOG","BROWSE_FILMS","BROWSE_AUDIO"]:
  actor.intent=intent
  assert(scene.desired_actor_animation(actor)=="IDLE_S")
 actor.intent="WATCH_FILM"
 assert(scene.desired_actor_animation(actor)=="IDLE_N")
 scene.yaw=0.42
 assert(scene.desired_actor_animation(actor)=="IDLE_NE")
 scene.free()
 print("GROUNDED_VIEW_POSE_PASS art_target=true no_uncalibrated_view=true cinema_camera_relative=true")
 quit(0)
