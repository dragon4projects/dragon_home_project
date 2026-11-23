extends SceneTree
const Scheduler = preload("res://scripts/life_scheduler_v2.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s := Scheduler.new()
	s.setup(["B","A","C"],10.0,8.0,0.0)
	var first := s.pop_due(10.0,2)
	assert(first.size()==2)
	assert(str(first[0]["id"])=="A")
	assert(str(first[1]["id"])=="B")
	assert(s.peek_due_at("C")==10.0)

	s.schedule_at("C",25.0,"LATE")
	s.wake("C",12.0,"URGENT")
	assert(s.peek_due_at("C")==12.0)
	s.wake("C",18.0,"TOO_LATE")
	assert(s.peek_due_at("C")==12.0)
	var due := s.pop_due(12.0,4)
	assert(due.size()==1 and str(due[0]["id"])=="C")
	assert(str(due[0]["reason"])=="URGENT")

	s.schedule_at("A",30.0,"PERSIST")
	var snap := s.snapshot()
	var restored := Scheduler.new()
	assert(restored.restore(snap,["A","C"],20.0,8.0,1.0))
	assert(restored.peek_due_at("A")==30.0)
	assert(not restored.due_at.has("B"))
	assert(restored.has_actor("C"))

	print("LIFE_SCHEDULER_V019_PASS stable_order=yes wake_earlier=yes budget=yes restore=yes")
	quit(0)
