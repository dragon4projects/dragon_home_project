extends SceneTree
const Bank=preload("res://scripts/asset_bank_resolver.gd")
const Intake=preload("res://scripts/complete_sprite_intake.gd")
const Nav=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func run()->void:
 var bank=Bank.new()
 if not check(bank.initialize(),"base registry"):return
 var original:Dictionary={}
 for id in bank.manifest.residents:
  for w in bank.manifest.residents[id].wardrobes:
   original[id+"|"+w]=bank._entry(id,w,"SIT").duplicate(true)
 var old_count:int=bank.install_depth7_intake()
 var intake=Intake.new()
 if not check(old_count==22,"legacy overlay missing"):return
 if not FileAccess.file_exists(Intake.ROOT+"frames.json"):
  var before:Dictionary=bank.manifest.duplicate(true)
  if not check(not intake.install(bank) and bank.manifest==before,"absent intake must fail without mutation"):return
  print("COMPLETE_SPRITE_MISSING_GUARD_PASS")
  quit(0);return
 if not check(intake.install(bank),intake.last_error):return
 if not check(intake.report.frames==204 and intake.report.groups==184 and intake.report.added==162 and intake.report.preserved==22,"unexpected intake coverage "+str(intake.report)):return
 for id in bank.manifest.residents:
  for w in bank.manifest.residents[id].wardrobes:
   if not check(bank._entry(id,w,"SIT")==original[id+"|"+w],"front SIT modified"):return
 var records=intake.read_json(Intake.ROOT+"frames.json")
 var count:=0
 for rec in records:
  var img:=Image.new()
  if not check(img.load("res://"+rec.path)==OK,"decode "+rec.path):return
  img.convert(Image.FORMAT_RGBA8)
  if not check(img.get_size()==Vector2i(rec.canvas[0],rec.canvas[1]),"dimensions "+rec.path):return
  var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(img)
  if not check(sprite.texture!=null,"Sprite3D "+rec.path):sprite.free();return
  sprite.free();count+=1
 var delta=intake.read_json(Intake.ROOT+"registry_delta.json")
 for row in delta.entries:
  var n:int=bank.creature_frame_count(row.actor_id,row.state) if row.wardrobe==null else bank.frame_count(row.actor_id,row.wardrobe,row.state)
  if not check(n==row.frames.size(),"runtime frame count "+str(row)):return
 var nav=Nav.new();nav.configure({})
 nav.install_depth7_pose_intake()
 var contacts:int=intake.install_poses(nav,bank)
 if not check(contacts>0,"no matching pose candidates"):return
 print("COMPLETE_SPRITE_INTAKE_PASS frames=",count," groups=",intake.report.groups," added=",intake.report.added," existing=",intake.report.preserved," matching_new_contacts=",contacts)
 quit(0)
