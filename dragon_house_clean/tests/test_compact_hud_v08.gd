extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_compact_hud_v08.json"
	root.add_child(scene)
	current_scene=scene
	assert(scene.hud_main_body != null)
	assert(not scene.hud_expanded and not scene.hud_main_body.visible,
		"House HUD must start compact, not obstruct the cinematic room")
	assert(scene.hud_brief != null and scene.hud_brief.text.contains("комнат"))
	assert(scene.hud_toggle_button.text=="☰ Меню")
	scene.toggle_hud()
	assert(scene.hud_expanded and scene.hud_main_body.visible)
	assert(scene.hud_toggle_button.text=="Скрыть ▲")
	assert(scene.hud_status.text.contains("видимых"))
	var options=scene.menu
	assert(options != null and options.item_count>0,"Collapsed UI must preserve build controls")
	scene.set_mode("ROOM")
	assert(scene.hud_main_body.visible,"Camera mode must not collapse menu behind user")
	assert(scene.hud_status.text.contains("Места действий:") or scene.selected_room=="")
	# Keyboard collapse, media still operable while hidden.
	var key:=InputEventKey.new()
	key.keycode=KEY_TAB
	key.pressed=true
	scene._input(key)
	assert(not scene.hud_expanded and not scene.hud_main_body.visible)
	scene.toggle_media_panel()
	assert(scene.media_panel.visible)
	scene.toggle_media_panel()
	assert(not scene.media_panel.visible)
	var actor: Dictionary=scene.world.residents["MANJKA"]
	assert(actor.get("active",false))
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	print("COMPACT_HUD_V08_PASS startup=compact Tab=toggle modes=stable media=available")
	quit(0)

