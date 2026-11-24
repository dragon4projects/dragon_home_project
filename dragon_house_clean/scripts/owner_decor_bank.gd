extends RefCounted
## Selected models from the existing Poly Haven decor harvest.
## The model layer is visual only; station identity and X/Z routing stay in World.
const ROOT := "res://assets/decor_bank/"
const REQUIRED := {
	"common":["sofa_02","chinese_armchair","gothic_coffee_table"],
	"cinema":["sofa_02","chinese_armchair"],
	"artifact":["wooden_display_shelves_01","chinese_commode"],
	"workshop":["wooden_table_02","metal_stool_02","worn_metal_rack"],
}

func model_path(asset: String) -> String:
	return ROOT+asset+"/model.gltf"

func ready_for(kind: String) -> bool:
	if not REQUIRED.has(kind):
		return false
	for asset in REQUIRED[kind]:
		if not ResourceLoader.exists(model_path(str(asset)), "PackedScene"):
			return false
	return true

func _collect_bounds(node: Node, inherited: Transform3D, boxes: Array[AABB]) -> void:
	var xf:Transform3D=inherited
	if node is Node3D:
		xf=inherited*(node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node:MeshInstance3D=node as MeshInstance3D
		if mesh_node.mesh!=null:
			boxes.append(xf*mesh_node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child,xf,boxes)

func _place(parent: Node3D, asset: String, x: float, z: float,
		height: float, max_width: float, max_depth: float, scale_at: Callable,
		station: String = "") -> bool:
	var packed:=ResourceLoader.load(model_path(asset),"PackedScene") as PackedScene
	if packed==null:
		push_error("Owner decor missing: "+asset)
		return false
	var instance:=packed.instantiate()
	var boxes:Array[AABB]=[]
	_collect_bounds(instance,Transform3D.IDENTITY,boxes)
	if boxes.is_empty():
		instance.free()
		push_error("Owner decor contains no mesh: "+asset)
		return false
	var bounds:AABB=boxes[0]
	for b in boxes:
		bounds=bounds.merge(b)
	if minf(bounds.size.x,minf(bounds.size.y,bounds.size.z))<=0.0001:
		instance.free()
		push_error("Owner decor invalid bounds: "+asset)
		return false
	var uniform:float=minf(height/bounds.size.y,
		minf(max_width/bounds.size.x,max_depth/bounds.size.z))
	var depth:float=float(scale_at.call(z))
	var center:Vector3=bounds.get_center()
	var wrapper:=Node3D.new()
	wrapper.name="Decor_%s_%d" % [asset,parent.get_child_count()]
	wrapper.position=Vector3(x*depth,0.025,z)
	wrapper.scale=Vector3.ONE*depth
	wrapper.set_meta("source_asset_id",asset)
	wrapper.set_meta("physical_x",x)
	wrapper.set_meta("physical_z",z)
	wrapper.set_meta("physical_width",bounds.size.x*uniform)
	wrapper.set_meta("physical_depth",bounds.size.z*uniform)
	wrapper.set_meta("station_furniture_id",station)
	parent.add_child(wrapper)
	var normalized:=Node3D.new()
	normalized.scale=Vector3.ONE*uniform
	normalized.position=Vector3(-center.x,-bounds.position.y,-center.z)*uniform
	wrapper.add_child(normalized)
	normalized.add_child(instance)
	return true

func _groups(spots: Array, kind: String) -> Array:
	var groups:Array=[]
	for raw in spots:
		if typeof(raw)!=TYPE_DICTIONARY:
			continue
		var id:String=str(raw.get("furniture_id",""))
		var station_kind:String=str(raw.get("kind",""))
		if id=="" or id=="DISPLAY_WALL":
			continue
		if kind in ["common","cinema"] and station_kind!="seat":
			continue
		if kind=="artifact" and not (id.to_lower().contains("cabinet") or id.to_lower().contains("shelf") or id.to_lower().contains("pedestal")):
			continue
		if kind=="workshop" and station_kind!="work":
			continue
		var p:Vector2=raw.get("offset",Vector2.ZERO)
		var found:bool=false
		for g in groups:
			if str(g["id"])==id and (g["points"][0] as Vector2).distance_to(p)<1.8:
				g["points"].append(p)
				found=true
				break
		if not found:
			groups.append({"id":id,"points":[p]})
	return groups

func populate(parent: Node3D, kind: String, width: int, spots: Array, scale_at: Callable) -> int:
	var start:int=parent.get_child_count()
	var span:float=float(width)*4.8
	var groups:Array=_groups(spots,kind)
	for group in groups:
		var points:Array=group["points"]
		var center:=Vector2.ZERO
		for p in points:
			center+=p
		center/=float(points.size())
		var id:String=str(group["id"])
		var lower:String=id.to_lower()
		var x:float=clampf(center.x,-span*0.5+0.65,span*0.5-0.65)
		match kind:
			"common","cinema":
				var asset:String="sofa_02" if points.size()>1 else "chinese_armchair"
				_place(parent,asset,x,clampf(center.y-0.16,-1.30,0.38),0.86,
					2.25 if points.size()>1 else 0.95,0.82,scale_at,id)
			"artifact":
				var is_shelf:bool=lower.contains("shelf")
				_place(parent,"wooden_display_shelves_01" if is_shelf else "chinese_commode",
					x,clampf(center.y-0.43,-1.58,0.25),
					1.75 if is_shelf else 0.86,1.22,0.56,scale_at,id)
			"workshop":
				if lower.contains("stool"):
					_place(parent,"metal_stool_02",x,center.y-0.06,0.46,0.42,0.42,scale_at,id)
				else:
					_place(parent,"wooden_table_02",x,clampf(center.y-0.36,-1.52,0.20),
						0.78,1.38,0.64,scale_at,id)
	match kind:
		"common":
			_place(parent,"gothic_coffee_table",0.0,0.28,0.48,1.18,0.60,scale_at)
		"artifact":
			# A shelf is a storage/display surface, not a procedural pedestal.
			# Keep it on the rear wall, away from standing approach points.
			var shelf_x:float=-span*0.5+0.78
			var has_shelf:bool=false
			for child in parent.get_children():
				if str(child.get_meta("source_asset_id",""))=="wooden_display_shelves_01":
					has_shelf=true
			if not has_shelf:
				_place(parent,"wooden_display_shelves_01",shelf_x,-1.57,1.78,1.22,0.58,scale_at)
			if groups.is_empty():
				_place(parent,"chinese_commode",span*0.5-0.85,-1.30,0.86,1.25,0.55,scale_at)
		"workshop":
			_place(parent,"worn_metal_rack",-span*0.5+0.72,-1.57,1.75,1.10,0.52,scale_at)
			if groups.is_empty():
				_place(parent,"wooden_table_02",0.0,-0.75,0.78,1.38,0.64,scale_at)
				_place(parent,"metal_stool_02",0.0,0.15,0.46,0.42,0.42,scale_at)
	return parent.get_child_count()-start
