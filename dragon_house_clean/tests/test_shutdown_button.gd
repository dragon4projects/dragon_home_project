extends SceneTree
class Fixture extends "res://scripts/main.gd":
 func _ready()->void:pass
 func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var scene=Fixture.new()
 root.add_child(scene)
 current_scene=scene
 scene.world.save_path="user://shutdown_button_qa.json"
 assert(scene.world.load_or_seed())
 scene.life.setup(scene.world)
 scene.semantic_view.install(scene.world,"HOUSE")
 scene.build_interface()
 var button:Button=scene.find_child("SaveAndExit",true,false)
 assert(button!=null and button.is_visible_in_tree() and not scene.hud_expanded)
 scene.world.sim_clock=123.456
 scene.life.clock=123.456
 button.pressed.emit()
 assert(scene.shutdown_requested and not scene.is_processing())
 var snapshot:Dictionary=scene.world._read_snapshot(scene.world.save_path)
 assert(absf(float(snapshot.sim_clock)-123.456)<0.00001)
 # Duplicate notification must not rotate the backup a second time.
 var primary:String=FileAccess.get_sha256(scene.world.save_path)
 var backup:String=FileAccess.get_sha256(scene.world.save_path+".bak")
 scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 assert(primary==FileAccess.get_sha256(scene.world.save_path))
 assert(backup==FileAccess.get_sha256(scene.world.save_path+".bak"))
 print("SHUTDOWN_BUTTON_PASS collapsed_menu=true real_signal=true final_snapshot=true duplicate_close_no_rotation=true")
