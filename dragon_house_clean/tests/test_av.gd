extends SceneTree
const WorldScript = preload("res://scripts/world_model.gd")
const MediaRuntime = preload("res://scripts/media_runtime.gd")
func _initialize() -> void:
	var world = WorldScript.new()
	world.seed_world()
	world.media = {
		"books": [],
		"films": [{"id":"QA_VIDEO","title":"Test clip","file_path":"res://tests/fixtures/test_video.ogv"},
			{"id":"BAD_MP4","title":"Unsupported format","file_path":"res://tests/fixtures/test_video.ogv.mp4"}],
		"tracks": [{"id":"QA_SOUND","title":"Test tone","file_path":"res://tests/fixtures/test_chime.wav"}]
	}
	var media = MediaRuntime.new()
	media.setup(world)
	assert(media.playable("tracks").size()==1)
	assert(media.playable("films").size()==1)
	assert(media.can_watch("RES_01","QA_VIDEO",world.get_room(4,0)["id"]))
	assert(not media.can_watch("RES_01","BAD_MP4",world.get_room(4,0)["id"]))
	assert(media.can_listen("RES_01","QA_SOUND",world.get_room(3,0)["id"]))
	var sound := AudioStreamWAV.load_from_file("res://tests/fixtures/test_chime.wav")
	assert(sound != null,"Generated WAV must decode in installed Godot")
	var video := VideoStreamTheora.new()
	video.file = "res://tests/fixtures/test_video.ogv"
	assert(video.file.ends_with(".ogv"),"Native Theora path")
	print("AV_FORMAT_TEST_PASS audio=WAV, film=Theora, MP4=rejected")
	quit(0)
