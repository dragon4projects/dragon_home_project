extends RefCounted
## Explicit, opt-in TEEA008 review. Never changes canonical world or approval.
const ROOT := "res://assets/teea008_review/decor_bank/"
const LAYOUT := "res://data/teea008_review/room_layouts_xz.json"
var layouts:Dictionary={}
var enabled:=false
var error:=""
func initialize() -> bool:
	layouts.clear()
	enabled=false
	error=""
	if OS.get_environment("DRAGON_TEEA008_REVIEW")!="1":
		return false
	var f:=FileAccess.open(LAYOUT,FileAccess.READ)
	if f==null:
		error="TEEA008 layout missing"
		return false
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):
		error="invalid candidate contract"
		return false
	for raw in doc.get("items",[]):
		if typeof(raw)!=TYPE_DICTIONARY or bool(raw.get("owner_approved",true)):
			error="invalid variant approval"
			layouts.clear()
			return false
		var id:String=str(raw.get("variant_id",""))
		if id=="" or layouts.has(id):
			error="invalid/duplicate variant"
			layouts.clear()
			return false
		for item in raw.get("instances",[]):
			var asset:String=str(item.get("asset_id",""))
			if asset=="" or not asset.is_valid_filename() or asset.contains("..") or not ResourceLoader.exists(ROOT+asset+"/model.gltf","PackedScene"):
				error="missing candidate asset "+asset
				layouts.clear()
				return false
		layouts[id]=raw
	enabled=layouts.size()==33
	return enabled

func variant(kind:String, width:int)->Dictionary:
	return layouts.get("%s/R%d" % [kind,width],{}) if enabled else {}

func populate(parent:Node3D, kind:String, width:int, scale_at:Callable)->int:
	var row:Dictionary=variant(kind,width)
	var count:=0
	for item in row.get("instances",[]):
		var asset:String=str(item["asset_id"])
		var position:Array=item["room_local_xyz"]
		var rotation:Array=item["rotation_deg_xyz"]
		var scene:=ResourceLoader.load(ROOT+asset+"/model.gltf","PackedScene") as PackedScene
		if scene==null:
			continue
		var wrapper:=Node3D.new()
		wrapper.name=str(item["instance_id"]).validate_node_name()
		var z:float=float(position[2])
		# Match existing artistic depth correction, while retaining unwarped
		# room coordinates as metadata for inspection.
		var depth:float=float(scale_at.call(z))
		wrapper.position=Vector3(float(position[0])*depth,float(position[1]),z)
		wrapper.rotation_degrees=Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2]))
		wrapper.scale=Vector3.ONE*float(item.get("uniform_scale",1.0))*depth
		wrapper.set_meta("candidate_instance_id",str(item["instance_id"]))
		wrapper.set_meta("candidate_asset_id",asset)
		wrapper.set_meta("physical_xyz",position)
		wrapper.set_meta("owner_approved",false)
		parent.add_child(wrapper)
		wrapper.add_child(scene.instantiate())
		count+=1
	return count
