extends SceneTree
const Bank=preload("res://scripts/teea008_review_bank.gd")
func _initialize()->void:
	call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var bank=Bank.new()
	assert(bank.initialize(),bank.error)
	var parent:=Node3D.new()
	root.add_child(parent)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	var count:=0
	var failures:Array=[]
	for key in bank.layouts:
		var parts:PackedStringArray=str(key).split("/")
		bank.populate(parent,parts[0],int(parts[1].trim_prefix("R")),func(_z):return 1.0)
		for aperture in get_nodes_in_group("teea008_media_surface"):
			var center:Vector3=aperture.global_position
			var id:String=str(aperture.get_meta("surface_id",""))
			for yaw in [-0.34,0.0,0.34]:
				camera.position=Vector3(sin(yaw)*8.0,2.4,cos(yaw)*8.0)
				camera.look_at(Vector3(0.0,1.5,0.0),Vector3.UP)
				await process_frame
				var pointer:Vector2=camera.unproject_position(center)
				var found:Dictionary=bank.aperture_hit(camera,pointer)
				if str(found.get("item_id",""))!=id:
					failures.append([id,yaw,found.get("item_id","")])
				count+=1
		for node in parent.get_children():
			node.free()
	print("APERTURE_YAW_PROBE checks=",count," failures=",failures)
	assert(count==96 and failures.is_empty())
	print("TEEA008_APERTURE_YAW_PASS")
	quit(0)
