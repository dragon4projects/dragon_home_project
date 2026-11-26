extends SceneTree
const Registry=preload("res://scripts/private_door_registry.gd")
const ROOT="user://house_content/door_notes/"
const MANIFEST="user://house_content/door_notes_manifest.json"
func _initialize()->void:
	call_deferred("run")
func write(path:String,body:String)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f:=FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_string(body)
	f.close()
func run()->void:
	# Dedicated test XDG_DATA_HOME, never actual private content.
	assert(OS.get_environment("DRAGON_QA_DOOR_FIXTURE")=="1")
	var p:=ROOT+"RES_24/00_дверь.md"
	write(p,"SYNTHETIC QA NOTE")
	var legacy:=ROOT+"RES_03/00_ДВЕРЬ.md"
	write(legacy,"UNVERIFIED FIXTURE")
	var r=Registry.new()
	assert(r.initialize())
	assert(not r.has_public_note("RES_24"))
	assert(not r.has_public_note("RES_03"))
	var entries={"RES_24":{"display_authorized":true,"sha256":FileAccess.get_sha256(p),"provenance":"synthetic QA"},"RES_08":{"display_authorized":false},"RES_99/..":{"display_authorized":true,"sha256":FileAccess.get_sha256(p),"provenance":"synthetic invalid"}}
	write(MANIFEST,JSON.stringify({"schema":1,"entries":entries}))
	assert(r.initialize())
	assert(r.has_public_note("RES_24"))
	assert(r.note_text("RES_24")=="SYNTHETIC QA NOTE")
	assert(not r.has_public_note("RES_08"))
	assert(not r.has_public_note("RES_99/.."))
	write(p,"TAMPERED")
	assert(not r.has_public_note("RES_24"))
	assert(r.note_text("RES_24")=="")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("VERIFIED_DOOR_NOTES_PASS explicit_binding=true digest=true revocation=true missing_blank=true")
	quit(0)
