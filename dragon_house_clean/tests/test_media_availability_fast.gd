extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var w=W.new();w.canonical_house_seed=true;w.seed_world()
 var m=M.new();m.setup(w)
 for i in range(500):
  w.media.films.append({"id":"QA_FILM_%d"%i,"simulation_only":true,"media_type":"film","runtime_seconds":90.0})
  w.media.tracks.append({"id":"QA_TRACK_%d"%i,"simulation_only":true,"autonomous_music":true,"runtime_seconds":180.0})
 var id:="RES_01";var now:=100.0
 for category in ["films","tracks"]:
  for available in [true,false]:
   for row in w.media[category]:row["simulation_only"]=available
   var t:=Time.get_ticks_usec()
   for i in range(100):
    if category=="films":assert(m.has_watch_choice(id,now)==available)
    else:assert(m.has_listen_choice(id,now)==available)
   var fast:int=Time.get_ticks_usec()-t
   t=Time.get_ticks_usec()
   for i in range(100):
    if category=="films":assert((not m.watch_candidates(id,now).is_empty())==available)
    else:assert((not m.listen_candidates(id,now).is_empty())==available)
   print("MEDIA_EXISTENCE ",category," available=",available," early_us=",fast," list_us=",Time.get_ticks_usec()-t)
 # Exact cooldown and missing-duration equivalence.
 for item in w.media.films:item["simulation_only"]=true;item["runtime_seconds"]=0
 w.media.films[-1]["runtime_seconds"]=60
 assert(m.has_watch_choice(id,now) and m.watch_candidates(id,now).size()==1)
 for item in w.media.tracks:item["simulation_only"]=true;item["runtime_seconds"]=0
 w.media.tracks[-1]["runtime_seconds"]=60
 assert(m.has_listen_choice(id,now) and m.listen_candidates(id,now).size()==1)
 print("MEDIA_AVAILABILITY_FAST_PASS")
 quit()
