extends RefCounted
## Local-only manual control interface. Explicit selection is a simulation
## instruction, not authentication as another person or evidence of consent.
const EDITOR=preload("res://scripts/local_house_editor.gd")
var scene
var editor=EDITOR.new()
var dialog:AcceptDialog
var first:OptionButton
var second:OptionButton
var action:OptionButton
var confirm:CheckBox
var status:Label
var mode:=""
var dx:SpinBox
var dz:SpinBox
const FURNITURE=preload("res://scripts/local_furniture_layout.gd")

func bind(s)->void:
 scene=s
 editor.setup(s.world,s.life,s.artifact_cubes)

func _picker(box:VBoxContainer,label:String)->OptionButton:
 var title:=Label.new();title.text=label;box.add_child(title)
 var p:=OptionButton.new();p.fit_to_longest_item=false;p.custom_minimum_size.x=480;box.add_child(p)
 return p

func _add(p:OptionButton,label:String,value)->void:
 p.add_item(label);p.set_item_metadata(p.item_count-1,value)

func _value(p:OptionButton):
 return p.get_item_metadata(p.selected) if p.selected>=0 else null

func _open(title:String)->VBoxContainer:
 if is_instance_valid(dialog):dialog.queue_free()
 dialog=AcceptDialog.new()
 dialog.title=title
 dialog.ok_button_text="Закрыть"
 scene.add_child(dialog)
 var col:=VBoxContainer.new();dialog.add_child(col)
 return col

func _finish(col:VBoxContainer,label:String)->void:
 confirm=CheckBox.new();confirm.text=label;col.add_child(confirm)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(status)
 var apply:=Button.new();apply.text="Применить";col.add_child(apply);apply.pressed.connect(_apply)
 dialog.popup_centered(Vector2i(620,390))

func open_doors()->void:
 mode="doors"
 var col:=_open("Локальные команды дверям")
 var expl:=Label.new()
 expl.text="Только явные команды симуляции. Не подтверждает согласие реального человека. Не открывает интерьер или личные записи."
 expl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(expl)
 first=_picker(col,"Комната")
 for r in scene.world.rooms:
  if scene.world.PrivateDoorAccess.valid_room(r):_add(first,str(r.get("display_name",r.id)),r.id)
 second=_picker(col,"Посетитель")
 for a in scene.world.residents.values():
  if a.get("active",false) and a.id!="MANJKA":_add(second,str(a.get("name",a.id)),a.id)
 action=_picker(col,"Команда")
 for row in [["Постучать (у порога)","knock"],["Войти по разрешению","enter"],["Выйти","leave_visit"],["Открыть дверь","open"],["Закрыть дверь","close"],["Режим тишины","quiet"],["Снять режим тишины","unquiet"],["Разрешить визит по стуку","answer"],["Отказать","deny"],["Постоянное приглашение","standing"],["Отозвать приглашение","revoke"]]:_add(action,row[0],row[1])
 _finish(col,"Подтверждаю явное разрешение на эту команду симуляции")
 first.item_selected.connect(func(_i):confirm.button_pressed=false)
 second.item_selected.connect(func(_i):confirm.button_pressed=false)
 action.item_selected.connect(func(_i):
  confirm.button_pressed=false
  confirm.text="Есть явное разрешение владельца комнаты на эту команду" if str(_value(action)) not in ["knock","enter","leave_visit"] else "Я явно задаю действие посетителя в симуляции")


func open_editor()->void:
 mode="editor"
 var col:=_open("Обстановка · измеренные места")
 first=_picker(col,"Предмет")
 for o in scene.world.objects.values():
  if editor.public_object(o.id) and o.get("viewer_category","")=="artifacts" and o.get("display_mode","")!="wall":_add(first,str(o.get("display_name",o.id)),{"kind":"artifact","id":o.id})
 for b in scene.world.media.get("books",[]):
  if bool(b.get("physical",true)) and b.get("holder_id","")=="" and scene.world.public_cutaway_allowed(scene.world.room_by_id(str(b.get("location_room_id","")))) and scene.world.public_cutaway_allowed(scene.world.room_by_id(str(b.get("home_room_id","")))):_add(first,str(b.get("title",b.id)),{"kind":"book","id":b.id})
 second=_picker(col,"Новая опора")
 first.item_selected.connect(func(_i):_refresh_options())
 _refresh_options()
 _finish(col,"Назначить выбранное место постоянным домом предмета")

func open_furniture()->void:
 mode="furniture"
 var col:=_open("Обстановка · перемещение мебели")
 first=_picker(col,"Общественная комната")
 for rid in scene.dense_v2.by_room:
  var r:Dictionary=scene.world.room_by_id(rid)
  if scene.world.public_cutaway_allowed(r):_add(first,str(r.get("display_name",rid)),rid)
 second=_picker(col,"Мебель и связанные опоры (не занятые)")
 first.item_selected.connect(func(_i):_refresh_furniture())
 for label in ["Сдвиг X (м)","Сдвиг глубины Z (м)"]:
  var l:=Label.new();l.text=label;col.add_child(l)
  var spin:=SpinBox.new();spin.min_value=-2.0;spin.max_value=2.0;spin.step=.05;col.add_child(spin)
  if label.begins_with("Сдвиг X"):dx=spin
  else:dz=spin
 _refresh_furniture()
 _finish(col,"Перенести мебель вместе с опорами и станциями; не менять комнату")

func _refresh_furniture()->void:
 second.clear()
 var rid=_value(first)
 if rid==null:return
 var compiled:Dictionary=scene.dense_v2.by_room[rid].compiled
 for p in compiled.placements:
  if FURNITURE.allowed(compiled,p):_add(second,str(p.asset)+" · "+str(p.id),p.id)

func _refresh_options()->void:
 second.clear()
 var item=_value(first)
 if item==null:return
 var options:Array=editor.artifact_options(item.id) if item.kind=="artifact" else editor.book_options(item.id)
 for opt in options:_add(second,opt.label,opt)

func _apply()->void:
 if not confirm.button_pressed:return
 confirm.button_pressed=false
 var a=_value(first)
 var b=_value(second)
 if a==null or b==null:return
 var ok:=false
 if mode=="doors":
  var room:Dictionary=scene.world.room_by_id(str(a))
  var op:String=str(_value(action))
  if not scene.world.PrivateDoorAccess.valid_room(room):return
  if op=="knock":ok=scene.world.control_private_door(a,b,"knock",b)
  elif op=="enter":ok=scene.life.begin_private_visit(b,a)
  elif op=="leave_visit":ok=scene.world.residents.get(b,{}).get("private_visit_room","")==a and scene.life.leave_private_visit(b)
  elif op in ["open","close","quiet","unquiet"]:
   ok=scene.world.control_private_door(a,room.owner_id,"open" if op in ["open","close"] else "quiet","",op in ["open","quiet"])
  else:
   ok=scene.world.control_private_door(a,room.owner_id,"answer" if op=="deny" else op,b,op!="deny")
 elif mode=="editor":
  ok=editor.move_artifact(a.id,b.room_id,b.slot_id) if a.kind=="artifact" else editor.move_book(a.id,b.room_id,b.slot_id)
  if ok:
   scene.life.refresh_changed_station_claims()
   scene.update_physical_objects()
   scene._refresh_conditional_dressing()
   _refresh_options()
 elif mode=="furniture":
  ok=FURNITURE.commit(scene,str(a),str(b),Vector2(dx.value,dz.value))
  if ok:dx.value=0;dz.value=0
 status.text="Команда выполнена." if ok else "Команда отклонена: условия доступа или размещения не выполнены."
