extends SceneTree
const R=preload("res://scripts/asset_bank_resolver.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var f=FileAccess.open("res://data/asset_proposals/DH_SPRITE_20261126_INTAKE/registry_delta.json",FileAccess.READ)
 var delta:Dictionary=JSON.parse_string(f.get_as_text())
 var r=R.new()
 assert(r.initialize())
 var count:=0
 for u in delta.entries:
  var a:String=u.actor_id
  var w=u.wardrobe
  var s:String=u.state
  var states:Dictionary=r.manifest.creatures[a].states if w==null else r.manifest.residents[a].wardrobes[w].states
  assert(states.get(s)==u.expected_previous_entry,str([a,w,s]))
  states[s]=u.entry
  for i in range(u.entry.frames.size()):
   var path:String="res://"+u.entry.frames[i]
   var img=Image.load_from_file(path)
   assert(img!=null and not img.is_empty() and img.get_format()==Image.FORMAT_RGBA8,path)
   var texture:Texture2D=r.creature_texture(a,s,i) if w==null else r.texture_for(a,w,s,i)
   assert(texture!=null,path)
   var sprite:=Sprite3D.new();sprite.texture=texture;root.add_child(sprite);sprite.free()
   count+=1
 assert(count==42 and delta.entries.size()==22)
 print("SPRITE66_INTAKE_PASS frames=",count," states=",delta.entries.size()," production_registry_unchanged=true")
 quit()
