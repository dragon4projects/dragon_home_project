extends RefCounted
# Only called after a domain-specific successful result, never on assignment.
const STEP:=0.012
const CAP:=0.3
const DECAY_HALF_LIFE:=14.0*86400.0

static func strength(actor:Dictionary,intent:String,now:float)->float:
 var base:float=clampf(float(actor.get("habits",{}).get(intent,0.0)),0.0,CAP)
 var row:Dictionary=actor.get("habit_success",{}).get(intent,{})
 if not row.has("last_success_at"):return base
 return base*pow(0.5,maxf(0.0,now-float(row["last_success_at"]))/DECAY_HALF_LIFE)

static func record(actor:Dictionary,intent:String,now:float,subject:String="",context:String="")->void:
 if intent=="" or not is_finite(now) or now<0:return
 var habits:Dictionary=actor.get("habits",{})
 habits[intent]=minf(CAP,strength(actor,intent,now)+STEP)
 actor["habits"]=habits
 var history:Dictionary=actor.get("habit_success",{})
 var row:Dictionary=history.get(intent,{})
 row["count"]=int(row.get("count",0))+1
 row["last_success_at"]=now
 row["last_room_id"]=str(actor.get("room_id",""))
 row["last_station_id"]=str(actor.get("station_anchor_id",""))
 row["last_subject_id"]=subject
 row["last_context"]=context
 var bucket:int=int(fposmod(now,86400.0)/21600.0)
 var buckets:Dictionary=row.get("time_buckets",{})
 buckets[str(bucket)]=int(buckets.get(str(bucket),0))+1
 row["time_buckets"]=buckets
 history[intent]=row
 actor["habit_success"]=history
 var recent:Array=actor.get("habit_recent",[])
 recent.append({"intent":intent,"at":now,"room_id":row["last_room_id"],"station_id":row["last_station_id"],"subject_id":subject,"context":context})
 if recent.size()>32:recent.pop_front()
 actor["habit_recent"]=recent
