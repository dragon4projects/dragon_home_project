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
	for key in bank.layouts:
		var row:Dictionary=bank.layouts[key]
		var parts:PackedStringArray=str(key).split("/")
		var width:int=int(parts[1].trim_prefix("R"))
		var count:int=bank.populate(parent,parts[0],width,func(_z):return 1.0)
		assert(count==row["instances"].size(),str(key))
		for node in parent.get_children():
			assert(not bool(node.get_meta("owner_approved",true)))
			assert(node.get_child_count()==1)
			node.free()
		total+=count
	print("TEEA008_REVIEW_BANK_PASS variants=33 instances=",total)
	quit(0)
