#https://github.com/ACB-prgm/Godot_Camera/blob/main/camera/Camera2D.gd
extends Camera2D

onready var shakeTimer = $Timer
onready var tween = $Tween

var shake_amount = 0
var default_offset = offset

const DEFAULT_LIMIT = 1100

func unlimit():
	limit_left = -100000
	limit_right = 100000

func limit():
	limit_left = DEFAULT_LIMIT
	limit_right = -DEFAULT_LIMIT

func move_to(pos):
	unlimit()
	global_position = pos

func return_to_player():
	limit()	
	position = Vector2.ZERO
	

func _ready():
	Globals.camera = self
	set_process(false)
	


func _process(delta):
	offset = Vector2(rand_range(-shake_amount, shake_amount), rand_range(-shake_amount, shake_amount)) * delta + default_offset


func shake(new_shake, shake_time=0.5, shake_limit=2000):
	shake_amount += new_shake
	if shake_amount > shake_limit:
		shake_amount = shake_limit
	
	shakeTimer.wait_time = shake_time
	
	tween.stop_all()
	set_process(true)
	shakeTimer.start()


func _on_Timer_timeout():
	shake_amount = 0
	set_process(false)
	
	tween.interpolate_property(self, "offset", offset, default_offset,
	0.1, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.start()
