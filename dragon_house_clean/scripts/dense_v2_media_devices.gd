extends RefCounted
const SPECS={
 "L2_cinema_F18":{"surface_id":"cinema.r3.film.screen","asset":"owner_theatre_screen","path":"res://assets/decor_bank/owner_theatre_screen/model.gltf","category":"films","center":Vector3(0,.8979505,.038),"size":Vector2(2.926616,1.661989),"hit_only":false},
 "L0_cinema_F18":{"surface_id":"cinema.r3.film.screen","asset":"owner_theatre_screen","path":"res://assets/decor_bank/owner_theatre_screen/model.gltf","category":"films","center":Vector3(0,.8979505,.038),"size":Vector2(2.926616,1.661989),"hit_only":false},
 "L2_music_W16":{"surface_id":"music.r3.audio.01","asset":"media_holder_audio","path":"res://assets/teea008_review/decor_bank/media_holder_audio/model.gltf","category":"tracks","center":Vector3(0,0,.045),"size":Vector2(.45,.45),"hit_only":false},
 "L2_music_D27":{"surface_id":"music.r3.audio.now_playing","asset":"cassette_player","path":"res://assets/teea008_review/decor_bank/cassette_player/model.gltf","category":"tracks","center":Vector3(0,.118409,.028),"size":Vector2(.12946,.236818),"hit_only":true},
 "L0_cinema_I96_DECOR_01":{"surface_id":"L0_cinema.DECOR_01.film.screen","asset":"classic_laptop","path":"res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","category":"films","center":Vector3(.000397,.214778,-.1335),"size":Vector2(.291,.237),"yaw":0.0,"hit_only":false,"room_key":"L0_cinema"},
 "L0_cinema_I96_DECOR_02":{"surface_id":"L0_cinema.DECOR_02.film.screen","asset":"owner_hp_notebook_lowpoly","path":"res://assets/decor_bank/owner_hp_notebook_lowpoly/model.gltf","category":"films","center":Vector3(.100,.132,0),"size":Vector2(.30,.19),"yaw":-90.0,"hit_only":false,"room_key":"L0_cinema"},
 "L0_cinema_I96_DECOR_03":{"surface_id":"L0_cinema.DECOR_03.film.screen","asset":"classic_laptop","path":"res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","category":"films","center":Vector3(.000397,.214778,-.1335),"size":Vector2(.291,.237),"yaw":0.0,"hit_only":false,"room_key":"L0_cinema"},
 "L0_cinema_I96_DECOR_04":{"surface_id":"L0_cinema.DECOR_04.film.screen","asset":"owner_hp_notebook_lowpoly","path":"res://assets/decor_bank/owner_hp_notebook_lowpoly/model.gltf","category":"films","center":Vector3(.100,.132,0),"size":Vector2(.30,.19),"yaw":-90.0,"hit_only":false,"room_key":"L0_cinema"},
 "L2_cinema_I96_DECOR_02":{"surface_id":"L2_cinema.DECOR_02.film.screen","asset":"owner_hp_notebook_lowpoly","path":"res://assets/decor_bank/owner_hp_notebook_lowpoly/model.gltf","category":"films","center":Vector3(.100,.132,0),"size":Vector2(.30,.19),"yaw":-90.0,"hit_only":false,"room_key":"L2_cinema"},
 "L2_cinema_I96_DECOR_03":{"surface_id":"L2_cinema.DECOR_03.film.screen","asset":"classic_laptop","path":"res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","category":"films","center":Vector3(.000397,.214778,-.1335),"size":Vector2(.291,.237),"yaw":0.0,"hit_only":false,"room_key":"L2_cinema"},
 "L2_cinema_I96_DECOR_04":{"surface_id":"L2_cinema.DECOR_04.film.screen","asset":"owner_hp_notebook_lowpoly","path":"res://assets/decor_bank/owner_hp_notebook_lowpoly/model.gltf","category":"films","center":Vector3(.100,.132,0),"size":Vector2(.30,.19),"yaw":-90.0,"hit_only":false,"room_key":"L2_cinema"},
 "L2_music_I96_DECOR_02":{"surface_id":"L2_music.DECOR_02.audio.device","asset":"cassette_player","path":"res://assets/teea008_review/decor_bank/cassette_player/model.gltf","category":"tracks","center":Vector3(0,.118409,.028),"size":Vector2(.12946,.236818),"yaw":0.0,"hit_only":true,"room_key":"L2_music"},
 "L2_music_I96_DECOR_03":{"surface_id":"L2_music.DECOR_03.audio.device","asset":"classic_laptop","path":"res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","category":"tracks","center":Vector3(.000397,.214778,-.1335),"size":Vector2(.291,.237),"yaw":0.0,"hit_only":false,"room_key":"L2_music"},
 "L2_music_I96_DECOR_07":{"surface_id":"L2_music.DECOR_07.audio.device","asset":"cassette_player","path":"res://assets/teea008_review/decor_bank/cassette_player/model.gltf","category":"tracks","center":Vector3(0,.118409,.028),"size":Vector2(.12946,.236818),"yaw":0.0,"hit_only":true,"room_key":"L2_music"},
 "L2_music_I96_DECOR_08":{"surface_id":"L2_music.DECOR_08.audio.device","asset":"portable_cassette_player","path":"res://assets/teea008_review/decor_bank/portable_cassette_player/model.gltf","category":"tracks","center":Vector3(0,.066,.021),"size":Vector2(.17,.13),"yaw":0.0,"hit_only":true,"room_key":"L2_music"},
 "L2_music_I96_DECOR_09":{"surface_id":"L2_music.DECOR_09.audio.device","asset":"classic_laptop","path":"res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","category":"tracks","center":Vector3(.000397,.214778,-.1335),"size":Vector2(.291,.237),"yaw":0.0,"hit_only":false,"room_key":"L2_music"},
 "L2_music_I96_DECOR_11":{"surface_id":"L2_music.DECOR_11.audio.device","asset":"cassette_player","path":"res://assets/teea008_review/decor_bank/cassette_player/model.gltf","category":"tracks","center":Vector3(0,.118409,.028),"size":Vector2(.12946,.236818),"yaw":0.0,"hit_only":true,"room_key":"L2_music"},
 "L2_music_I96_DECOR_13":{"surface_id":"L2_music.DECOR_13.audio.device","asset":"cassette_player","path":"res://assets/teea008_review/decor_bank/cassette_player/model.gltf","category":"tracks","center":Vector3(0,.118409,.028),"size":Vector2(.12946,.236818),"yaw":0.0,"hit_only":true,"room_key":"L2_music"},
 "L2_music_I96_DECOR_14":{"surface_id":"L2_music.DECOR_14.audio.device","asset":"portable_cassette_player","path":"res://assets/teea008_review/decor_bank/portable_cassette_player/model.gltf","category":"tracks","center":Vector3(0,.066,.021),"size":Vector2(.17,.13),"yaw":0.0,"hit_only":true,"room_key":"L2_music"}
}
static func mount(wrapper:Node3D,p:Dictionary,room_id:String)->bool:
 if room_id=="" or not SPECS.has(str(p.id)):return false
 var spec:Dictionary=SPECS[p.id]
 if p.asset!=spec.asset or p.path!=spec.path:return false
 var anchor:=Node3D.new()
 anchor.name="ActualMediaAperture"
 anchor.position=spec.center
 anchor.rotation_degrees.y=float(spec.get("yaw",0.0))
 anchor.set_meta("surface_id",spec.surface_id)
 anchor.set_meta("surface_category",spec.category)
 anchor.set_meta("surface_size",spec.size)
 anchor.set_meta("carrier_hit_only",spec.hit_only)
 anchor.set_meta("room_id",room_id)
 anchor.set_meta("dense_media_device",str(p.id))
 wrapper.add_child(anchor)
 anchor.add_to_group("teea008_media_surface")
 return true
static func spec_for(room:Dictionary,surface_id:String)->Dictionary:
 var layout:String=str(room.get("dense_v2_layout",""))
 if layout=="":return {}
 for id in SPECS:
  var spec:Dictionary=SPECS[id]
  if spec.surface_id!=surface_id:continue
  var room_key:String=str(spec.get("room_key",str(id).get_slice("_F",0) if str(id).contains("_F") else "L2_music"))
  if layout!="dense_v2_"+room_key+"/R3":continue
  return {"legacy_runtime_category":spec.category,"room_variant":str(room.type)+"/R3","binding_alias":"music.r3.audio.01" if spec.category=="tracks" and not spec.has("room_key") else surface_id,"carrier_instance_id":id,"dense_device":true}
 return {}
