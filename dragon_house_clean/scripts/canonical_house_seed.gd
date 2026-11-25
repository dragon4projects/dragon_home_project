extends RefCounted
## Approved building envelope. 15 modules / floor, six levels, three shafts.
## No runtime merge: every record creates exactly one physical immutable room.
const REVISION := "CANONICAL_HOUSE_20261125_V1"
const LEVELS := [3,2,1,0,-1,-2]
const SHAFTS := [-7,0,7]
const PUBLIC_FLOORS := {
	2: [[-6,"cinema","Кинотеатр"],[-3,"rest","Гостиная"],[1,"music","Музыкальный салон"],[4,"library","Библиотека"]],
	1: [[-6,"rest","Гостиная с диванами"],[-3,"common","Каминный зал"],[1,"artifact","Галерея артефактов"],[4,"study","Кабинет"]],
	0: [[-6,"library","Читальный зал"],[-3,"workshop","Мастерская"],[1,"cinema","Второй кинотеатр"],[4,"music","Музыкальная студия"]]
}

static func _add(world, x:int, level:int, kind:String, width:int, title:String, candidate_id:String="")->Dictionary:
	var room:Dictionary=world.make_room(x,level,kind,width,true)
	room["display_name"]=title
	room["architecture_revision"]=REVISION
	if candidate_id!="":
		room["candidate_room_id"]=candidate_id
	return room

static func build(world)->void:
	for level in LEVELS:
		for x in SHAFTS:
			_add(world,int(x),int(level),"lift",1,"Лифт")
		if PUBLIC_FLOORS.has(level):
			for spec in PUBLIC_FLOORS[level]:
				_add(world,int(spec[0]),int(level),str(spec[1]),3,str(spec[2]))
			continue
		for x in range(-6,0):
			if level==-2 and x==-6:
				_add(world,x,int(level),"guest",2,"Кентавр","guest_centaur_01")
			elif level==-2 and x==-5:
				continue
			else:
				_add(world,x,int(level),"private",1,"Резерв")
		for x in range(1,7):
			if level==-2 and x==1:
				_add(world,x,int(level),"guest",1,"Вампирша","guest_vampire_01")
			elif level==-2 and x==6:
				_add(world,x,int(level),"guest",1,"Миу","guest_miu_01")
			else:
				_add(world,x,int(level),"private",1,"Резерв")

static func assign_homes(world,profiles:Array)->void:
	var homes:Array=[]
	for room in world.rooms:
		if str(room.get("type",""))=="private":
			homes.append(room)
	for i in range(mini(profiles.size(),homes.size())):
		var actor_id:String=str(profiles[i]["id"])
		var room:Dictionary=homes[i]
		room["owner_id"]=actor_id
		room["display_name"]=str(profiles[i].get("display_name",actor_id))
		if world.residents.has(actor_id):
			world.residents[actor_id]["home_room_id"]=str(room["id"])
