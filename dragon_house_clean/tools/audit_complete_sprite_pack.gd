extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:=OS.get_cmdline_user_args()
 assert(args.size()==1 and ProjectSettings.load_resource_pack(args[0],true))
 var base:="res://data/asset_proposals/DH_SPRITE_20261126_COMPLETE/"
 var f:=FileAccess.open(base+"frames.json",FileAccess.READ)
 assert(f!=null)
 var records=JSON.parse_string(f.get_as_text())
 var pf:=FileAccess.open("res://data/integration_candidates/TEEA008_POSE_EXPORT_PROOF.json",FileAccess.READ)
 assert(pf!=null)
 var proof=JSON.parse_string(pf.get_as_text())
 assert(records.size()==204)
 assert(FileAccess.file_exists("res://data/integration_candidates/DENSE_V2_SERVICES_OWNER_QA.enabled"))
 for rec in records:
  var p:String="res://"+rec.path
  assert(proof.frames.get(p,"")==rec.sha256,p)
  var tex:=ResourceLoader.load(p,"Texture2D") as Texture2D
  assert(tex!=null and tex.get_size()==Vector2(rec.canvas[0],rec.canvas[1]),p)
 print("COMPLETE_SPRITE_PACK_AUDIT_PASS 204 frames; owner QA marker present")
 quit(0)
