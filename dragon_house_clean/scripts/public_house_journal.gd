extends RefCounted
## Public projection only. Raw journal and causal store remain diagnostic.
const CATEGORY_NAMES={"life":"Занятия","social":"Общение","media":"Книги и медиа","objects":"Предметы","creatures":"Живность"}
const EVENTS={
 "PUBLIC_ACTIVITY_STARTED":["life","начала занятие"],
 "PAIR_STARTED":["social","начался разговор"],"PAIR_COMPLETED":["social","разговор завершён"],
 "GROUP_STARTED":["social","началась встреча"],"GROUP_COMPLETED":["social","встреча завершена"],
 "GROUP_JOINED":["social","присоединилась к разговору"],"GROUP_LEFT":["social","покинула разговор"],
 "BOOK_READING_START":["media","начала читать"],"BOOK_READING_RESUME":["media","продолжила чтение"],
 "BOOK_READING_PAUSE":["media","прервала чтение"],"BOOK_READING_FINISH":["media","закончила чтение"],
 "BOOK_PICKED_UP_AT_SHELF":["media","взяла книгу"],"BOOK_RETURNED_AT_SHELF":["media","вернула книгу"],
 "BOOK_RESTORED_HOME":["media","книга возвращена на полку"],
 "MEDIA_SESSION_STARTED":["media","началось прослушивание или просмотр"],"MEDIA_ATTENDANCE_JOINED":["media","присоединилась к просмотру или прослушиванию"],
 "CINEMA_UNIT_COMPLETED":["media","просмотр завершён"],"MUSIC_TRACK_COMPLETED":["media","прослушивание завершено"],
 "OBJECT_PICKED_UP":["objects","переносит предмет"],"OBJECT_STASHED":["objects","спрятала предмет"],
 "OBJECT_LOST_FOUND":["objects","предмет найден"],"OBJECT_RESTORED_HOME":["objects","предмет возвращён на место"],
 "OBJECT_HOUSEKEEPING_RETURNED":["objects","предмет убран"],"OBJECT_VIEWED":["objects","рассмотрела предмет"],
 "CREATURE_ROAMED":["creatures","переместилась"],"CREATURE_REGISTERED":["creatures","в Доме появилась живность"]
}
const ACTIONS={"REST":"отдыхает","SLEEP":"спит","WORK_CREATE":"занимается делами","WATCH_FIRE":"смотрит на огонь","PURPOSEFUL_EXPLORE":"осматривает Дом","VIEW_ART":"рассматривает артефакты","BROWSE_BOOK_CATALOG":"просматривает книжный каталог","BROWSE_FILMS":"выбирает фильм","BROWSE_AUDIO":"выбирает музыку"}
const ROOM_NAMES={"arrival":"Вход","corridor":"Переход","common":"Каминный зал","rest":"Гостиная","study":"Кабинет","library":"Библиотека","cinema":"Кинотеатр","music":"Музыкальный салон","workshop":"Мастерская","artifact":"Галерея","kitchen":"Кухня / бар","guest":"Гостевая","lift":"Лифт"}

func room_label(room:Dictionary)->String:
 return str(room.get("display_name",ROOM_NAMES.get(str(room.get("type","")),"Помещение")))

func actor_label(world,id:String)->String:
 var actor:Dictionary=world.residents.get(id,world.creatures.get(id,{}))
 return str(actor.get("name","Житель")) if not actor.is_empty() else "Дом"

func status(world,life,actor:Dictionary)->String:
 if not bool(actor.get("active",false)):return "не представлена"
 var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
 if not world.public_cutaway_allowed(room):
  if world.allows_transit(room) and str(actor.get("phase",""))=="travel" and float(actor.get("z",0))>=1.35:return "проходит по Дому"
  return "вне публичного обзора"
 if str(actor.get("phase","idle"))=="idle":return "свободна"
 return life.status(actor)

func project(world,entry:Dictionary)->Dictionary:
 var event:String=str(entry.get("event",""))
 if not EVENTS.has(event) or not bool(entry.get("public_projection_allowed",false)):return {}
 var ids:Array=entry.get("public_room_ids",[])
 if ids.is_empty():return {}
 var names:Array[String]=[]
 for id in ids:
  var room:Dictionary=world.room_by_id(str(id))
  # Access can be revoked since the event was recorded.
  if not world.public_cutaway_allowed(room):return {}
  names.append(room_label(room))
 var spec:Array=EVENTS[event]
 var action:String=spec[1]
 if event=="PUBLIC_ACTIVITY_STARTED":
  action=str(ACTIONS.get(str(entry.get("details",{}).get("intent","")),"начала занятие"))
 var subject:String=str(entry.get("subject_id",""))
 var title:String=""
 if str(spec[0])=="media":
  for kind in ["books","films","tracks"]:
   for item in world.media.get(kind,[]):
    if str(item.get("id",""))==subject:
     title=str(item.get("title",""))
     break
 elif str(spec[0])=="objects":
  var obj:Dictionary=world.physical_object(subject)
  # Do not expose a title for an object now kept outside public rooms.
  var location:String=str(obj.get("current_room_id",""))
  var holder:String=str(obj.get("current_holder_id",""))
  if holder!="":
   var carrier:Dictionary=world.residents.get(holder,world.creatures.get(holder,{}))
   location=str(carrier.get("room_id",""))
  if not world.public_cutaway_allowed(world.room_by_id(location)):return {}
  title=str(obj.get("display_name",""))
 if title!="":action+=" «"+title+"»"
 var actor_id:String=str(entry.get("actor_id",""))
 var participants:Array=[actor_id]
 if str(spec[0])=="social":
  # IDs used only as filter keys, never displayed as text.
  for id in entry.get("details",{}).get("members",[]):
   if not participants.has(id):participants.append(id)
 var seconds:int=maxi(0,int(entry.get("sim_clock",0)))
 var stamp:String="Д%d %02d:%02d"%[seconds/86400+1,(seconds/3600)%24,(seconds/60)%60]
 return {"category":spec[0],"actors":participants,"rooms":ids,"text":stamp+" · "+actor_label(world,actor_id)+" — "+action+" · "+" → ".join(names)}

func lines(world,actor_id:String="",room_id:String="",category:String="",limit:int=30)->Array[String]:
 var out:Array[String]=[]
 var entries:Array=world.journal_entries(256)
 for i in range(entries.size()-1,-1,-1):
  var row:Dictionary=project(world,entries[i])
  if row.is_empty() or (actor_id!="" and not row.actors.has(actor_id)) or (room_id!="" and not row.rooms.has(room_id)) or (category!="" and row.category!=category):continue
  out.append(row.text)
  if out.size()>=limit:break
 return out
