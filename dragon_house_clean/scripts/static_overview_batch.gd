extends RefCounted
## Rendering-only room-local batching. Never crosses a room visibility or
## privacy boundary. Originals remain as named authored model nodes.
const MAX_VERTICES:=24000
const MAX_SOURCE_VERTICES:=4000

func _eligible(mesh:MeshInstance3D,root:Node3D)->bool:
	if not mesh.is_visible_in_tree() or mesh.mesh==null or mesh.mesh.get_surface_count()!=1:return false
	if mesh.skin!=null or mesh.get_blend_shape_count()>0 or mesh.material_overlay!=null or mesh.transparency!=0.0:return false
	if mesh.visibility_range_begin!=0.0 or mesh.visibility_range_end!=0.0 or mesh.extra_cull_margin!=0.0:return false
	if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:return false
	var mat:Material=mesh.get_active_material(0)
	if not mat is StandardMaterial3D or mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or mat.next_pass!=null:return false
	if mat.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or mat.uv1_triplanar or mat.uv2_triplanar:return false
	if not mesh.mesh is ArrayMesh or mesh.mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:return false
	var node:Node=mesh
	while node!=root:
		if node==null or node.is_in_group("canonical_conditional_dressing") or node.is_in_group("low_end_micro_detail") or node is Skeleton3D:return false
		if node.get_parent()==root and not node.find_children("*","AnimationPlayer",true,false).is_empty():return false
		node=node.get_parent()
	var xf:Transform3D=root.global_transform.affine_inverse()*mesh.global_transform
	var scale_value:Vector3=xf.basis.get_scale()
	if xf.basis.determinant()<=0.0 or not is_equal_approx(scale_value.x,scale_value.y) or not is_equal_approx(scale_value.x,scale_value.z):return false
	return true

func batch(root:Node3D)->Dictionary:
	var stats:Dictionary={"sources":0,"batches":0,"vertices":0,"saved":0}
	if root==null or root.has_meta("static_overview_batch"):return stats
	var groups:Dictionary={}
	var exact:Dictionary={}
	for raw in root.find_children("*","MeshInstance3D",true,false):
		var mesh:MeshInstance3D=raw
		if not _eligible(mesh,root):continue
		var key:String=str(mesh.mesh.get_instance_id())+"|"+str(mesh.get_active_material(0).get_instance_id())+"|"+str(mesh.layers)+"|"+str(mesh.lod_bias)
		if not exact.has(key):exact[key]=[]
		exact[key].append(mesh)
	for items in exact.values():
		if items.size()>1:_commit_instances(root,items,stats)
	for raw in root.find_children("*","MeshInstance3D",true,false):
		var mesh:MeshInstance3D=raw
		if not _eligible(mesh,root) or mesh.name.begins_with("OverviewStaticBatch_"):continue
		# Do not bake away the imported LOD chain. RenderingServer exposes it.
		var surface:Dictionary=RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),0)
		if not surface.get("lods",{}).is_empty():continue
		var count:int=mesh.mesh.surface_get_array_len(0)
		if count<=0 or count>MAX_SOURCE_VERTICES:continue
		var fmt:int=mesh.mesh.surface_get_format(0)
		# SurfaceTool supports standard vertex channels; no custom, bones or weights.
		if fmt & (Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3|Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS):continue
		var key:String=str(mesh.get_active_material(0).get_instance_id())+"|"+str(fmt)+"|"+str(mesh.layers)+"|"+str(mesh.lod_bias)
		if not groups.has(key):groups[key]=[]
		groups[key].append(mesh)
	for group in groups.values():
		var chunk:Array=[]
		var vertices:=0
		for mesh in group:
			var n:int=mesh.mesh.surface_get_array_len(0)
			if vertices+n>MAX_VERTICES:
				_commit(root,chunk,vertices,stats)
				chunk=[]
				vertices=0
			chunk.append(mesh)
			vertices+=n
		_commit(root,chunk,vertices,stats)
	root.set_meta("static_overview_batch",stats)
	return stats

func _commit(root:Node3D,items:Array,vertices:int,stats:Dictionary)->void:
	if items.size()<2:return
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inverse:Transform3D=root.global_transform.affine_inverse()
	for mesh in items:tool.append_from(mesh.mesh,0,inverse*mesh.global_transform)
	var first:MeshInstance3D=items[0]
	tool.set_material(first.get_active_material(0))
	var merged:ArrayMesh=tool.commit()
	if merged==null or merged.get_surface_count()!=1:return
	var batch_node:=MeshInstance3D.new()
	batch_node.name="OverviewStaticBatch_%d"%int(stats["batches"])
	batch_node.mesh=merged
	batch_node.layers=first.layers
	batch_node.cast_shadow=first.cast_shadow
	batch_node.lod_bias=first.lod_bias
	root.add_child(batch_node)
	for mesh in items:
		mesh.visible=false
		mesh.set_meta("overview_batched",true)
	stats["sources"]+=items.size()
	stats["batches"]+=1
	stats["vertices"]+=vertices
	stats["saved"]+=items.size()-1

func _commit_instances(root:Node3D,items:Array,stats:Dictionary)->void:
	var first:MeshInstance3D=items[0]
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=first.mesh
	mm.instance_count=items.size()
	var inverse:Transform3D=root.global_transform.affine_inverse()
	for i in range(items.size()):mm.set_instance_transform(i,inverse*items[i].global_transform)
	var node:=MultiMeshInstance3D.new()
	node.name="OverviewInstanceBatch_%d"%int(stats["batches"])
	node.multimesh=mm
	node.material_override=first.get_active_material(0)
	node.cast_shadow=first.cast_shadow
	node.layers=first.layers
	node.lod_bias=first.lod_bias
	root.add_child(node)
	for mesh in items:
		mesh.visible=false
		mesh.set_meta("overview_batched",true)
	stats["sources"]+=items.size()
	stats["batches"]+=1
	stats["saved"]+=items.size()-1
