extends SceneTree
const Bank=preload("res://scripts/teea008_review_bank.gd")
func _initialize()->void:
	call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var bank=Bank.new()
	assert(bank.initialize(),bank.error)
	assert(bank.layouts.size()==33)
	var parent:=Node3D.new()
	root.add_child(parent)
	var total:=0
	var aperture_count:=0
	assert(bank.surfaces.size()==32)
	for key in bank.layouts:
		var row:Dictionary=bank.layouts[key]
		var parts:PackedStringArray=str(key).split("/")
		var width:int=int(parts[1].trim_prefix("R"))
		var count:int=bank.populate(parent,parts[0],width,func(_z):return 1.0)
		assert(count==row["instances"].size(),str(key))
		for aperture in get_nodes_in_group("teea008_media_surface"):
			assert(not bool(aperture.get_meta("owner_approved",true)))
			var surface_id:String=str(aperture.get_meta("surface_id",""))
			assert(bank.surfaces.has(surface_id))
			aperture_count+=1
		for node in parent.get_children():
			assert(not bool(node.get_meta("owner_approved",true)))
			assert(node.get_child_count()>=1)
			node.free()
		total+=count
	assert(total==219 and aperture_count==32)
	print("TEEA008_REVIEW_BANK_PASS variants=33 instances=",total," apertures=",aperture_count)
	quit(0)
