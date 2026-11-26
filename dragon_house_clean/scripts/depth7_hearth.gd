extends RefCounted
# Canonical depth-seven hearth; owner geometry, attached to live room root.
const DEPTH=preload("res://scripts/depth7_space.gd")
const BANK=preload("res://scripts/teea008_review_bank.gd")
const BANDS=[1.65,0.65,-.85,-1.75,-3.60,-4.50,-6.65,-8.05]
const HW=7.2
const RADIUS=.325
var stage:Node3D
var bank=BANK.new()
var blockers:Array[AABB]=[]
var placements:Array=[]
var seat_candidates:Array=[]
var picture_slots:Array=[]
var seat_group:String="left_conversation"
var mats:Dictionary={}
func material(id:String,color:Color,tex:String="",uv:Vector3=Vector3.ONE)->StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color;m.roughness=.88
 if tex!="":m.albedo_texture=load("res://assets/materials/texture_albedo/"+tex);m.uv1_scale=uv;m.uv1_triplanar=true
 mats[id]=m
 return m
func box(id:String,p:Vector3,d:Vector3,m:Material,yaw:float=0)->MeshInstance3D:
 var n:=MeshInstance3D.new();n.name=id;var mesh:=BoxMesh.new();mesh.size=d;n.mesh=mesh;n.material_override=m
 stage.add_child(n);n.position=p;n.rotation_degrees.y=yaw
 return n
func light(p:Vector3,color:Color,energy:float,range_m:float)->void:
 var l:=OmniLight3D.new();stage.add_child(l);l.position=p;l.light_color=color;l.light_energy=energy;l.omni_range=range_m;l.omni_attenuation=1.1;l.shadow_enabled=false
# Same 0.85 -> 1.0 linear correction as production room_space_v2,
# normalized over the expanded seven-band floor. Keep owner X/Z anchors.
func depth_scale(z:float)->float:
 return DEPTH.scale_at(z)
func asset(id:String,at:Vector3,scale_value:float=1.0,yaw:float=0,blocking:bool=false)->AABB:
 var base_scale:float=scale_value
 if id in ["sofa_03","blendkit_sofa_repaired","ArmChair_01","gothic_coffee_table"]:
  scale_value*=depth_scale(at.z)
 var path:String=bank._asset_path(id)
 assert(ResourceLoader.exists(path,"PackedScene"),path)
 var n:=Node3D.new();n.name=id;stage.add_child(n);n.position=at;n.scale=Vector3.ONE*scale_value;n.rotation_degrees.y=yaw
 var instance=load(path).instantiate();n.add_child(instance)
 if id=="sketchfab_fireplace_animated":
  for mi in n.find_children("*","MeshInstance3D",true,false):
   for si in range(mi.mesh.get_surface_count()):
    var original=mi.get_active_material(si)
    if original!=null and original.resource_name.to_lower() in ["stone","bricks"]:
     mi.set_surface_override_material(si,mats["stone"])
  for player in n.find_children("*","AnimationPlayer",true,false):
   for anim in player.get_animation_list():
    if anim!="RESET":player.play(anim);break
 if id=="wooden_bookshelf_worn":
  for mi in n.find_children("*","MeshInstance3D",true,false):mi.material_override=mats["wood"]
 return AABB()
func dragon_crop()->AABB:
 var source:Node3D=load(bank._asset_path("owner_sleeping_dragon")).instantiate()
 stage.add_child(source)
 var n:=Node3D.new();n.name="SleepingDragonCroppedPilot";stage.add_child(n)
 var bounds:=AABB();var first:=true
 var surfaces:=0
 for m in source.find_children("*","MeshInstance3D",true,false):
  var mi:MeshInstance3D=m
  for k in range(mi.mesh.get_surface_count()):
   var a:Array=mi.mesh.surface_get_arrays(k)
   var verts:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for v in range(verts.size()):indices.append(v)
   var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
   st.set_material(mi.get_active_material(k))
   var triangles:=0
   for t in range(0,indices.size(),3):
    var center:=Vector3.ZERO
    for j in range(3):center+=stage.to_local(mi.to_global(verts[indices[t+j]]))/3.0
    if center.x<-.081 or center.x>.075 or center.z<-.074 or center.z>.083:continue
    for j in range(3):
     var ix:int=indices[t+j]
     if a[Mesh.ARRAY_NORMAL] is PackedVector3Array and a[Mesh.ARRAY_NORMAL].size()==verts.size():st.set_normal(((stage.global_transform.basis.inverse()*mi.global_transform.basis)*a[Mesh.ARRAY_NORMAL][ix]).normalized())
     if a[Mesh.ARRAY_TEX_UV] is PackedVector2Array and a[Mesh.ARRAY_TEX_UV].size()==verts.size():st.set_uv(a[Mesh.ARRAY_TEX_UV][ix])
     st.add_vertex(stage.to_local(mi.to_global(verts[ix])))
    triangles+=1
   if triangles==0:continue
   var mesh:=st.commit();var node:=MeshInstance3D.new();node.mesh=mesh;n.add_child(node)
   var b:AABB=mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false;surfaces+=1
 source.free()
 assert(not first and surfaces>0)
 var scale_value:float=minf(5.40/bounds.size.x,4.30/bounds.size.z)
 n.scale=Vector3.ONE*scale_value
 n.position=Vector3(6.99-bounds.size.x*scale_value*.5,-bounds.position.y*scale_value,-7.70+bounds.size.z*scale_value*.5)-Vector3(bounds.get_center().x*scale_value,0,bounds.get_center().z*scale_value)
 return n.transform*bounds
func arch(cx:float,z:float)->void:
 # Decorative masonry arch in front of actual rear wall. Recessed dark pane.
 box("WindowRecess",Vector3(cx,1.41,z-.075),Vector3(1.23,1.72,.09),mats["glass"])
 # Insets remain deliberately dark, not a fabricated exterior view.
 for dx in [-.61,.61]:
  box("WindowInnerFrame",Vector3(cx+dx,1.41,z+.015),Vector3(.07,1.72,.09),mats["trim"])
 box("WindowTopFrame",Vector3(cx,2.26,z+.015),Vector3(1.24,.07,.09),mats["trim"])
 for sx in [-.70,.70]:
  box("StoneJamb",Vector3(cx+sx,.94,z),Vector3(.24,1.88,.22),mats["stone"])
 for i in range(11):
  var t:float=PI*float(i)/10.0
  var n=box("ArchStone",Vector3(cx+.70*cos(t),1.83+.70*sin(t),z),Vector3(.27,.30,.24),mats["stone"])
  n.rotation.z=t-PI*.5
 box("WindowSill",Vector3(cx,.54,z+.09),Vector3(1.62,.14,.44),mats["stone"])
 box("WindowMullion",Vector3(cx,1.42,z+.02),Vector3(.07,1.71,.08),mats["wood"])
 box("WindowCross",Vector3(cx,1.48,z+.02),Vector3(1.35,.06,.08),mats["wood"])
func populate(parent:Node3D)->Node3D:
 stage=Node3D.new();stage.name="Depth7Hearth";parent.add_child(stage)
 material("stone",Color("#6e6155"),"stone_pathway_diff_2k.jpg",Vector3(.65,.65,.65))
 material("rock",Color("#807469"),"dark_rock_diff_2k.jpg",Vector3(.68,.68,.68))
 material("floor",Color("#877567"),"stone_pathway_diff_2k.jpg",Vector3(.55,.55,.55))
 material("wood",Color("#69503b"),"weathered_brown_planks_diff_1k.jpg",Vector3(.7,.7,.7))
 material("glass",Color("#23333a"))
 material("trim",Color("#3d2921"),"natural_walnut_veneer_diff_1k.jpg",Vector3(.8,.8,.8))
 material("brass",Color("#9b7545"))
 material("canvas_blank",Color("#b9a58a"))
 material("hearth_tile",Color("#51483e"),"tiger_rock_diff_2k.jpg",Vector3(.80,.80,.80))
 box("Floor",Vector3(0,-.16,-3.20),Vector3(14.4,.32,9.70),mats["floor"])
 box("RearWall",Vector3(0,1.48,-8.19),Vector3(14.4,2.96,.28),mats["rock"])
 # Real shallow floor finishes, flush with walking surface; no navigation blockers.
 for i in range(15):
  var x:float=-6.72+float(i)*.96
  box("AisleFlagstone",Vector3(x,.002,1.13),Vector3(.94,.004,.94),mats["hearth_tile"])
 for x in [-6.96,6.96]:
  box("FloorEdge",Vector3(x,.005,-3.20),Vector3(.16,.01,9.70),mats["trim"])
 box("RearSkirting",Vector3(0,.12,-7.93),Vector3(14.1,.24,.14),mats["trim"])
 # Individual staggered stone blocks, material reused, shallow relief only.
 for row in range(6):
  for col in range(18):
   var x:float=-6.85+col*.8+(.4 if row%2 else 0)
   if x>7.0:continue
   box("Masonry",Vector3(x,.245+row*.48,-8.045),Vector3(.78,.46,.13),mats["stone"])
 for x in [-6.97,-3.48,.0,3.48,6.97]:
  box("RearPost",Vector3(x,1.52,-7.86),Vector3(.23,3.04,.28),mats["wood"])
 box("RearBeam",Vector3(0,2.94,-7.78),Vector3(14.4,.26,.38),mats["wood"])
 # Low cutaway frame, open ceiling and front; no fake wall across the aisle.
 for x in [-7.1,7.1]:
  box("SideReturn",Vector3(x,1.45,-5.65),Vector3(.20,2.9,4.60),mats["rock"])
 for x in [-5.7,5.4]:arch(x,-7.87)
 # Band 7: actual furniture, fireplace centered, rear sofa/book storage.
 asset("wooden_bookshelf_worn",Vector3(-3.15,0,-7.36),1.12,0,true)
 asset("wooden_bookshelf_worn",Vector3(2.06,0,-7.36),.92,0,true)
 var fireplace:=asset("sketchfab_fireplace_annabelle_fibonacci",Vector3(-.18,0,-7.43),1.70,0,true)
 box("ChimneyBreast",Vector3(-.18,2.47,-7.84),Vector3(2.72,1.09,.33),mats["stone"])
 box("ChimneyMantel",Vector3(-.18,1.99,-7.58),Vector3(3.02,.15,.54),mats["wood"])
 # Ten independently named, replaceable wall slots. No invented owner artwork.
 for row in range(2):
  for col in range(5):
   var idx:int=row*5+col+1
   var c:=Vector3(-.18+(col-2)*.55,2.26+row*.34,-7.60)
   var frame:=box("HEARTH_PICTURE_%02d"%idx,c,Vector3(.51,.30,.065),mats["brass"])
   frame.set_meta("slot_id","HEARTH_PICTURE_%02d"%idx)
   frame.set_meta("artwork_path","")
   picture_slots.append({"id":frame.get_meta("slot_id"),"center_xyz":[c.x,c.y,c.z+.04],"aperture_m":[.44,.23],"artwork_path":""})
   var canvas:=box("BlankCanvas_%02d"%idx,c+Vector3(0,0,.04),Vector3(.44,.23,.02),mats["canvas_blank"])
   # Explicit slot files only. The user override survives exports and upgrades.
   var slot_path:String="res://assets/hearth_pictures/HEARTH_PICTURE_%02d.png"%idx
   var user_path:String="user://hearth_pictures/HEARTH_PICTURE_%02d.png"%idx
   if FileAccess.file_exists(user_path):slot_path=user_path
   var texture:Texture2D=null
   if ResourceLoader.exists(slot_path,"Texture2D"):
    texture=load(slot_path) as Texture2D
   elif FileAccess.file_exists(slot_path):
    var img:=Image.load_from_file(slot_path)
    if img!=null and not img.is_empty():texture=ImageTexture.create_from_image(img)
   if texture!=null and texture.get_height()>0:
    var aspect:float=float(texture.get_width())/float(texture.get_height())
    var height:float=minf(.23,.44/aspect)
    var picture:=MeshInstance3D.new()
    picture.name="Artwork_%02d"%idx
    var quad:=QuadMesh.new();quad.size=Vector2(height*aspect,height)
    picture.mesh=quad
    var m:=StandardMaterial3D.new();m.albedo_texture=texture;m.roughness=.9
    picture.material_override=m;stage.add_child(picture);picture.position=canvas.position+Vector3(0,0,.012)
    frame.set_meta("artwork_path",slot_path);picture_slots.back()["artwork_path"]=slot_path
    picture_slots.back()["image_size_m"]=[height*aspect,height]
 box("HearthApron",Vector3(-.18,.004,-6.53),Vector3(3.35,.008,.78),mats["hearth_tile"])
 asset("sofa_03",Vector3(-5.33,0,-7.32),1.0,0,true)
 asset("common_woven_rug",Vector3(-4.85,.008,-6.14),1.65)
 asset("common_woven_rug",Vector3(-.10,.007,-5.22),.86)
 asset("wooden_lantern_01",Vector3(-1.92,.005,-6.18),1.15)
 asset("vintage_grandfather_clock_01",Vector3(-2.09,0,-7.38),1.0,0,true)
 for cx in [-3.15,2.06]:
  var ratio:float=1.0 if cx<0 else .92/1.12
  for y in [.22,.64,1.06,1.48]:
   for dx in [-.34,.27]:
    asset("book_encyclopedia_set_01",Vector3(cx+dx*ratio,y*ratio,-7.28),.87*ratio)
  asset("potted_plant_04",Vector3(cx,2.20*ratio,-7.36),1.0)
 # Timber rafters and rear shelf sconces create framed architectural bays.
 for x in [-6.85,-3.48,0.0,3.48,6.85]:
  box("CeilingRafter",Vector3(x,3.04,-6.95),Vector3(.23,.25,2.05),mats["wood"])
  if x!=0.0:
   var brace:=box("TimberBrace",Vector3(x+.25,2.69,-7.70),Vector3(.69,.18,.24),mats["wood"])
   brace.rotation.z=.70
 asset("wooden_lantern_01",Vector3(1.52,0,-6.64),1.2)
 asset("wicker_basket_01",Vector3(-1.95,0,-6.65),1.6)
 # A third timber bay gives the rear room a recognizable scale.
 for x in [-6.86,6.86]:
  box("SideHighBeam",Vector3(x,2.99,-5.70),Vector3(.25,.25,3.72),mats["wood"])
 for x in [-6.93,6.93]:
  box("SideColumn",Vector3(x,1.49,-5.02),Vector3(.19,2.98,.22),mats["wood"])
 # Band 6 is local approach pockets; band 5 stays traversable.
 # Band 4: inward-facing chairs and real coffee/bar table.
 # U-shaped group: back sofa +Z, left sofa +X, right chair -X.
 asset("blendkit_sofa_repaired",Vector3(-6.56,0,-6.02),.88,90,true)
 asset("ArmChair_01",Vector3(-3.30,0,-5.80),.85,-90,true)
 asset("gothic_coffee_table",Vector3(-4.96,0,-5.70),.90,0,true)
 asset("brass_candleholders",Vector3(-4.96,.3069*depth_scale(-5.70),-5.70),.45*depth_scale(-5.70))
 # Band 2: seating group at front left, free center and right for Dragon.
 asset("common_woven_rug",Vector3(-4.30,.006,-.15),1.78)
 asset("ArmChair_01",Vector3(-5.93,0,-.12),1.10,75,true)
 asset("gothic_coffee_table",Vector3(-4.28,0,-.12),1.13,0,true)
 asset("ArmChair_01",Vector3(-2.72,0,-.12),1.10,-75,true)
 asset("brass_candleholders",Vector3(-4.29,.3853*depth_scale(-.12),-.12),.55*depth_scale(-.12))
 asset("potted_plant_01",Vector3(-6.52,0,-5.0),.8,0,true)
 # Owner's marked layout: two rows and one side sofa oriented toward the fire.
 # Keep the existing left conversation groups and add seven independently measured pieces.
 seat_group="hearth_view"
 asset("blendkit_sofa_repaired",Vector3(-1.88,0,-5.40),.88,180,true)
 asset("blendkit_sofa_repaired",Vector3(-.45,0,-2.70),.88,180,true)
 asset("blendkit_sofa_repaired",Vector3(.20,0,-5.45),.76,-140,true)
 # Dragon group: side sofa +X, front sofa -Z, two inward angled chairs.
 seat_group="dragon_view"
 asset("blendkit_sofa_repaired",Vector3(1.48,0,-5.55),.78,90,true)
 asset("blendkit_sofa_repaired",Vector3(4.85,0,-2.10),.88,180,true)
 asset("ArmChair_01",Vector3(2.40,0,-2.25),.92,145,true)
 asset("ArmChair_01",Vector3(6.45,0,-2.25),.92,-160,true)
 seat_group=""
 # Owner dragon: uniform scale, source proportions, rear-right nook.
 var dragon:=dragon_crop()
 assert(absf(dragon.end.x-6.99)<.01)
 assert(absf(dragon.position.z+7.70)<.01)
 assert(absf(dragon.position.y)<.02)
 # Wall lights and rear shelves, using real existing decor.
 for x in [-6.65,-3.45,3.48,6.75]:
  asset("industrial_wall_lamp",Vector3(x,2.12,-7.70),1.0)
  light(Vector3(x,2.05,-6.95),Color("#ffbd72"),1.3,4.1)
 light(Vector3(-.18,1.10,-6.48),Color("#ff9d42"),2.6,4.3)
 light(Vector3(-4.9,1.75,-5.78),Color("#ffcb94"),.85,3.1)
 light(Vector3(.50,1.75,-4.18),Color("#ffe1b5"),.85,2.8)
 box("RearCeilingSlab",Vector3(0,3.17,-7.37),Vector3(14.4,.19,1.40),mats["rock"])
 box("CeilingFrontHeader",Vector3(0,3.04,-6.63),Vector3(14.4,.23,.24),mats["wood"])
 light(Vector3(-4.3,2.65,-.95),Color("#ffd8a4"),1.45,5.0)
 light(Vector3(4.9,2.5,-5.4),Color("#ffc08b"),1.45,5.1)
 return stage
