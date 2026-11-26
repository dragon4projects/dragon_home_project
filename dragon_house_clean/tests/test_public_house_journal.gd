extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const P=preload("res://scripts/public_house_journal.gd")
class Fixture extends "res://scripts/main.gd":
 func _ready()->void:pass
 func _process(_delta:float)->void:pass
func _initialize():call_deferred("run")
func run():
 var w=W.new()
 w.canonical_house_seed=true
 w.seed_world()
 var life=L.new()
 life.setup(w)
 var p=P.new()
 var a:Dictionary=w.residents.RES_01
 var b:Dictionary=w.residents.RES_02
 var public_room:Dictionary=w.room_by_id("ROOM_0027")
 var private_room:Dictionary=w.room_by_id(a.home_room_id)
 var guest:Dictionary=w.get_room(-6,-2)
 assert(w.register_guest_actor("NPC_CENTAUR","Кентавр",guest.id,"centaur"))
 assert(w.configure_guest_room(guest.id,"NPC_CENTAUR"))
 assert(not guest.is_empty())
 a.merge({"active":true,"room_id":public_room.id,"phase":"perform","intent":"READ_BOOK","activity_media_category":"books","activity_media_id":"QA_PUBLIC_BOOK"},true)
 b.merge({"active":true,"room_id":public_room.id},true)
 w.media["books"]=[{"id":"QA_PUBLIC_BOOK","title":"Том для проверки"},{"id":"SECRET","title":"PRIVATE_PAYLOAD"}]
 w.sim_clock=3675
 w.journal.clear()
 w._append_journal("BOOK_READING_START",a.id,"QA_PUBLIC_BOOK","",public_room.id)
 w._append_journal("GROUP_STARTED",b.id,"PAIR_SESSION_001","",public_room.id,{"members":[a.id,b.id]})
 w._append_journal("LIFE_PLANNER_RAN",a.id,a.id,"TECH_REASON","READ_BOOK",{"secret":"RAW_PAYLOAD"})
 w._append_journal("CREATURE_ACCESS_REJECTED","UNKNOWN","UNKNOWN","",private_room.id)
 assert(p.lines(w).size()==2)
 assert(p.lines(w,a.id,public_room.id,"social").size()==1)
 assert(p.lines(w,b.id,public_room.id,"media").is_empty())
 assert(p.lines(w,a.id,public_room.id,"media")[0].contains("Том для проверки"))
 assert(p.lines(w)[0].contains("01:01"))
 assert(not "\n".join(p.lines(w)).contains("ROOM_"))
 assert(not "\n".join(p.lines(w)).contains("PAIR_SESSION"))
 a.room_id=private_room.id
 a.activity_media_id="SECRET"
 w._append_journal("BOOK_READING_START",a.id,"SECRET","",public_room.id)
 assert(p.status(w,life,a)=="вне публичного обзора")
 a.phase="travel"
 a.z=1.5
 assert(p.status(w,life,a)=="проходит по Дому")
 a.room_id=public_room.id
 a.phase="idle"
 assert(p.status(w,life,a)=="свободна")
 assert(p.lines(w).size()==2)
 # Guest revocation hides previous public event; private event remains hidden on reopening.
 assert(w.set_guest_room_open(guest.id,true))
 b.room_id=guest.id
 w._append_journal("PUBLIC_ACTIVITY_STARTED",b.id,b.id,"",guest.id,{"intent":"WATCH_FIRE"})
 assert(p.lines(w).size()==3)
 assert(w.set_guest_room_open(guest.id,false))
 w._append_journal("PUBLIC_ACTIVITY_STARTED",b.id,b.id,"",guest.id,{"intent":"SLEEP"})
 assert(p.lines(w).size()==2)
 assert(w.set_guest_room_open(guest.id,true))
 assert(p.lines(w).size()==3)
 # Legacy, unknown and explicitly restricted object events never enter public view.
 w.journal.append({"event":"BOOK_READING_START","actor_id":a.id,"subject_id":"SECRET","to":public_room.id})
 w._append_journal("OBJECT_VIEWED",a.id,"SECRET","",public_room.id,{"visibility":"owner_controlled","event_room_id":public_room.id})
 assert(p.lines(w).size()==3)
 assert(not "\n".join(p.lines(w)).contains("PRIVATE_PAYLOAD"))
 var scene=Fixture.new()
 root.add_child(scene)
 scene.world=w
 scene.life=life
 scene.journal_actor_filter=OptionButton.new()
 scene.journal_room_filter=OptionButton.new()
 scene.journal_category_filter=OptionButton.new()
 scene.journal_text=Label.new()
 for control in [scene.journal_actor_filter,scene.journal_room_filter,scene.journal_category_filter,scene.journal_text]:scene.add_child(control)
 scene._refresh_journal_filters()
 for i in range(scene.journal_room_filter.item_count):assert(str(scene.journal_room_filter.get_item_metadata(i))!=private_room.id)
 for i in range(scene.journal_category_filter.item_count):
  if str(scene.journal_category_filter.get_item_metadata(i))=="media":scene.journal_category_filter.select(i)
 scene.update_journal()
 assert(scene.journal_text.text.contains("Том для проверки") and not scene.journal_text.text.contains("встреча"))
 assert(w.journal.any(func(e):return e.event=="LIFE_PLANNER_RAN"))
 print("PUBLIC_HOUSE_JOURNAL_PASS filters=3 timestamp=true private_redaction=true revocation=true diagnostic_retained=true")
 quit(0)
