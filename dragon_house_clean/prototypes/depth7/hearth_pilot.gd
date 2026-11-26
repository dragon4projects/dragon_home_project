extends SceneTree
# Isolated visual/geometry prototype. No production room, state or save mutation.
const BANK=preload("res://scripts/teea008_review_bank.gd")
const BANDS=[1.65,0.65,-1.55,-3.80,-4.75,-5.65,-6.65,-8.05]
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
var cam:Camera3D
func _initialize()->void:call_deferred("run")
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
func asset(id:String,at:Vector3,scale_value:float=1.0,yaw:float=0,blocking:bool=false)->AABB:
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
 var bounds:=AABB();var first:=true
 for m in n.find_children("*","MeshInstance3D",true,false):
  var b:AABB=m.global_transform*m.get_aabb()
  bounds=b if first else bounds.merge(b);first=false
 assert(not first,id)
 if blocking:
  assert(bounds.position.x>=-HW-.01 and bounds.end.x<=HW+.01 and bounds.position.z>=BANDS[7]-.01 and bounds.end.z<=BANDS[0]+.01,str([id,bounds]))
  for b in blockers:
   assert(minf(b.end.x,bounds.end.x)-maxf(b.position.x,bounds.position.x)<.005 or minf(b.end.z,bounds.end.z)-maxf(b.position.z,bounds.position.z)<.005,str(["overlap",id,b,bounds]))
  blockers.append(bounds)
 placements.append({"asset":id,"position":[at.x,at.y,at.z],"scale":scale_value,"yaw":yaw,"bounds_min":[bounds.position.x,bounds.position.y,bounds.position.z],"bounds_max":[bounds.end.x,bounds.end.y,bounds.end.z],"blocking":blocking})
 if id in ["sofa_03","blendkit_sofa_repaired","ArmChair_01"]:
  var xs:Array=[-.45,.45] if id!="ArmChair_01" else [0.0]
  for sx in xs:
   var local:=Vector3(sx,0,.15)
   var world:Vector3=n.to_global(local)
   var surface_y:float=mesh_top(n,Vector2(world.x,world.z))
   assert(surface_y>.30 and surface_y<.65,str([id,surface_y]))
   var forward:Vector3=n.global_transform.basis.z.normalized()
   var foot:Vector3=n.to_global(Vector3(sx,0,.54 if id!="ArmChair_01" else .43))
   var seat_id:String="HEARTH_SEAT_%02d"%(seat_candidates.size()+1)
   seat_candidates.append({"id":seat_id,"asset":id,"seat_surface_xyz":[world.x,surface_y,world.z],"floor_feet_candidate_xyz":[foot.x,0,foot.z],"facing_xyz":[forward.x,0,forward.z],"yaw":yaw,"group":seat_group})
 return bounds
func mesh_top(node:Node3D,xz:Vector2)->float:
 var y:float=-1.0
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var m:MeshInstance3D=mesh
  for si in range(m.mesh.get_surface_count()):
   var a:Array=m.mesh.surface_get_arrays(si)
   var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
   if ix.is_empty():
    for j in range(v.size()):ix.append(j)
   for k in range(0,ix.size(),3):
    var p:Vector3=m.to_global(v[ix[k]])
    var q:Vector3=m.to_global(v[ix[k+1]])
    var r:Vector3=m.to_global(v[ix[k+2]])
    var hit=Geometry3D.ray_intersects_triangle(Vector3(xz.x,3.0,xz.y),Vector3.DOWN,p,q,r)
    if hit==null:hit=Geometry3D.ray_intersects_triangle(Vector3(xz.x,3.0,xz.y),Vector3.DOWN,r,q,p)
    if hit!=null:y=maxf(y,hit.y)
 return y
func validate_seats()->int:
 var total:=0
 for seat in seat_candidates:
  var c:Array=seat["seat_surface_xyz"]
  var f:Array=seat["facing_xyz"]
  var at:=Vector2(c[0],c[2])
  var forward:=Vector2(f[0],f[2])
  var side:=Vector2(forward.y,-forward.x)
  var group:String=seat.get("group","")
  if group in ["hearth_view","dragon_view"]:
   var focal:=Vector2(-.18,-7.43) if group=="hearth_view" else Vector2(4.85,-5.55)
   assert(forward.dot((focal-at).normalized())>.45,str(["wrong facing",seat,focal]))
  var found:=false
  # Same-side approach first, then adjacent lateral access; no teleport claim.
  for dist in [.60,.75,.90,1.05,1.20]:
   if found:break
   for lateral in [0.0,-.20,.20,-.40,.40,-.60,.60,-.80,.80]:
    var goal:Vector2=at+forward*dist+side*lateral
    if not clear(goal):continue
    if not reachable(Vector2(-7.05,1.15),goal) or not reachable(Vector2(7.05,1.15),goal):continue
    seat["approach_xz"]=[goal.x,goal.y]
    found=true;total+=2;break
  assert(found,str(["seat approach unavailable",seat]))
 return total
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
    for j in range(3):center+=mi.to_global(verts[indices[t+j]])/3.0
    if center.x<-.081 or center.x>.075 or center.z<-.074 or center.z>.083:continue
    for j in range(3):
     var ix:int=indices[t+j]
     if a[Mesh.ARRAY_NORMAL] is PackedVector3Array and a[Mesh.ARRAY_NORMAL].size()==verts.size():st.set_normal((mi.global_transform.basis*a[Mesh.ARRAY_NORMAL][ix]).normalized())
     if a[Mesh.ARRAY_TEX_UV] is PackedVector2Array and a[Mesh.ARRAY_TEX_UV].size()==verts.size():st.set_uv(a[Mesh.ARRAY_TEX_UV][ix])
     st.add_vertex(mi.to_global(verts[ix]))
    triangles+=1
   if triangles==0:continue
   var mesh:=st.commit();var node:=MeshInstance3D.new();node.mesh=mesh;n.add_child(node)
   var b:AABB=mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false;surfaces+=1
 source.free()
 assert(not first and surfaces>0)
 var scale_value:float=minf(5.40/bounds.size.x,4.30/bounds.size.z)
 n.scale=Vector3.ONE*scale_value
 n.position=Vector3(6.99-bounds.size.x*scale_value*.5,-bounds.position.y*scale_value,-7.70+bounds.size.z*scale_value*.5)-Vector3(bounds.get_center().x*scale_value,0,bounds.get_center().z*scale_value)
 var final:=n.global_transform*bounds
 for b in blockers:
  assert(minf(b.end.x,final.end.x)-maxf(b.position.x,final.position.x)<.005 or minf(b.end.z,final.end.z)-maxf(b.position.z,final.position.z)<.005)
 blockers.append(final)
 placements.append({"asset":"owner_sleeping_dragon","derivative":"central spatial crop; original material/UV; no new body mesh","scale":scale_value,"bounds_min":[final.position.x,final.position.y,final.position.z],"bounds_max":[final.end.x,final.end.y,final.end.z],"blocking":true})
 print("DRAGON_CROP source=",bounds," scale=",scale_value," final=",final)
 return final
func clear(p:Vector2)->bool:
 if p.x< -HW+.08 or p.x>HW-.08 or p.y<BANDS[7]+RADIUS or p.y>BANDS[0]-RADIUS:return false
 for b in blockers:
  if p.x>b.position.x-RADIUS and p.x<b.end.x+RADIUS and p.y>b.position.z-RADIUS and p.y<b.end.z+RADIUS:return false
 return true
func reachable(start:Vector2,goal:Vector2)->bool:
 # Conservative 0.10m occupancy grid; axis edges checked at midpoint.
 var step:=.10
 var origin:=Vector2(-7.12,-7.70)
 var a:=Vector2i(roundi((start.x-origin.x)/step),roundi((start.y-origin.y)/step))
 var b:=Vector2i(roundi((goal.x-origin.x)/step),roundi((goal.y-origin.y)/step))
 if not clear(start) or not clear(goal) or not clear(origin+Vector2(a)*step) or not clear(origin+Vector2(b)*step):return false
 var pending:Array[Vector2i]=[a];var seen:Dictionary={a:true};var k:=0
 while k<pending.size():
  var q:=pending[k];k+=1
  if q==b:return true
  for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var nxt:Vector2i=q+d
   if seen.has(nxt):continue
   var p:=origin+Vector2(nxt)*step
   if not clear(p) or not clear(p-Vector2(d)*step*.5):continue
   seen[nxt]=true;pending.append(nxt)
 return false
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
func scale_actor(id:String,world_pos:Vector3)->void:
 var image:Image=Image.load_from_file("res://assets/residents/"+id+"/wardrobes/HOME/IDLE_NE/0001.png")
 assert(image!=null and not image.is_empty())
 var tex:Texture2D=ImageTexture.create_from_image(image)
 if image.is_compressed():image.decompress()
 var used:Rect2i=image.get_used_rect()
 if used.size.y<=0:return
 var sp:=Sprite3D.new()
 sp.name="ScaleReference_"+id
 sp.texture=tex
 sp.pixel_size=1.70/float(used.size.y)
 sp.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
 sp.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
 sp.no_depth_test=false
 stage.add_child(sp)
 sp.position=world_pos+Vector3(0,(float(used.end.y)-256)*sp.pixel_size,0)

func capture(path:String)->void:
 for i in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(path)==OK)
func run()->void:
 stage=Node3D.new();root.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("#171315")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("#e5c7ad");env.environment.ambient_light_energy=.36
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 stage.add_child(env)
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
   var slot_path:String="res://prototypes/depth7/hearth_pictures/HEARTH_PICTURE_%02d.png"%idx
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
 asset("brass_candleholders",Vector3(-4.96,.3069,-5.70),.45)
 # Band 2: seating group at front left, free center and right for Dragon.
 asset("common_woven_rug",Vector3(-4.30,.006,-.76),1.78)
 asset("ArmChair_01",Vector3(-5.93,0,-.68),1.10,75,true)
 asset("gothic_coffee_table",Vector3(-4.28,0,-.62),1.13,0,true)
 asset("ArmChair_01",Vector3(-2.72,0,-.70),1.10,-75,true)
 asset("brass_candleholders",Vector3(-4.29,.3853,-.62),.55)
 asset("potted_plant_01",Vector3(-6.52,0,-3.95),.8,0,true)
 # Owner's marked layout: two rows and one side sofa oriented toward the fire.
 # Keep the existing left conversation groups and add seven independently measured pieces.
 seat_group="hearth_view"
 asset("blendkit_sofa_repaired",Vector3(-.45,0,-4.85),.88,180,true)
 asset("blendkit_sofa_repaired",Vector3(-.45,0,-2.65),.88,180,true)
 asset("blendkit_sofa_repaired",Vector3(1.38,0,-5.65),.88,-90,true)
 # Dragon group: side sofa +X, front sofa -Z, two inward angled chairs.
 seat_group="dragon_view"
 asset("blendkit_sofa_repaired",Vector3(1.38,0,-3.25),.88,90,true)
 asset("blendkit_sofa_repaired",Vector3(4.85,0,-1.55),.88,180,true)
 asset("ArmChair_01",Vector3(2.40,0,-.45),.92,145,true)
 asset("ArmChair_01",Vector3(6.45,0,-.48),.92,-160,true)
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
 var key:=DirectionalLight3D.new();stage.add_child(key);key.rotation_degrees=Vector3(-38,-20,0);key.light_color=Color("#ffe3c3");key.light_energy=.38
 # Full front aisle continuous, rear lanes accessible on left and central gaps.
 for i in range(95):
  assert(clear(Vector2(-7.05+14.10*float(i)/94.0,1.15)),"front aisle blocked")
 # Latest owner layout has furniture crossing rear band centerlines.
 # Front aisle remains continuous. Test reachable pockets instead of falsely
 # claiming uninterrupted straight rear aisles through the new rows.
 var targets=[Vector2(-4.9,-2.65),Vector2(-4.6,-4.78),Vector2(-3.65,-6.72),Vector2(-.18,-6.35),Vector2(-4.28,-1.82),Vector2(-5.33,-6.57),Vector2(-5.80,-5.70),Vector2(-4.04,-5.80),Vector2(4.85,-2.65)]
 var route_count:=0
 for q in targets:
  assert(clear(q),str(["approach",q]))
  for e in [Vector2(-7.05,1.15),Vector2(7.05,1.15)]:
   assert(reachable(e,q),str(["unreachable",e,q]));route_count+=1
 var seat_routes:=validate_seats()
 assert(seat_candidates.size()==19 and picture_slots.size()==10)
 print("HEARTH_SEAT_CONTACT_PASS seats=",seat_candidates.size()," routes=",seat_routes)
 print("DEPTH7_OWNER_LAYOUT_GEOMETRY_PASS dragon=",dragon," routes=",route_count," assets=",placements.size())
 var f=FileAccess.open("/home/user/dragon_qa/iter59_placement.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"bands_front_to_back":BANDS,"room_width":14.4,"dragon_bounds":[dragon.position,dragon.size],"placements":placements,"route_checks":route_count,"seat_route_checks":seat_routes,"seat_candidates":seat_candidates,"picture_slots":picture_slots},"  "));f.close()
 if DisplayServer.get_name()=="headless":
  print("HEARTH_HEADLESS_PASS");quit();return
 scale_actor("RES_07",Vector3(0.35,0,1.15))
 cam=Camera3D.new();stage.add_child(cam);cam.projection=Camera3D.PROJECTION_PERSPECTIVE;cam.fov=25.0;cam.current=true
 cam.position=Vector3(-.5,7.2,20.0);cam.look_at(Vector3(0,1.05,-3.35))
 await capture("/home/user/dragon_qa/iter59_hearth.png")
 cam.position=Vector3(-8,11,20);cam.look_at(Vector3(0,.75,-3.35));cam.fov=27.0
 await capture("/home/user/dragon_qa/iter59_oblique.png")
 # Technical plan, same scene, visible seven bands, not a generated drawing.
 for i in range(BANDS.size()):
  var m:=StandardMaterial3D.new();m.albedo_color=Color("#d8b078");m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  box("BandBoundary",Vector3(0,.025,BANDS[i]),Vector3(14.4,.016,.025),m)
 for i in range(7):
  var label:=Label3D.new();label.text=str(i+1);label.font_size=45;label.modulate=Color("#fff2ce");label.pixel_size=.008;label.rotation_degrees.x=-90
  stage.add_child(label);label.position=Vector3(-7.03,.06,(BANDS[i]+BANDS[i+1])*.5)
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.position=Vector3(0,22,-3.2);cam.look_at(Vector3(0,0,-3.2),Vector3(0,0,-1));cam.size=10.6
 await capture("/home/user/dragon_qa/iter59_plan.png")
 print("DEPTH7_OWNER_LAYOUT_RENDER_PASS 3")
 quit()
