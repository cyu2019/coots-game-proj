extends CanvasLayer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var fading = false

var health = 8

enum {DEFAULT, DEAD, ENDING}
var state = DEFAULT
# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.ui = self
	$FadeToBlack.visible = true
	Globals.player.connect("health_changed", self, "_on_health_change")
	get_tree().paused = false

func _on_health_change(amt):
	health += amt

func fade_to_black():
	get_tree().paused = true
	fading = true

func on_faded():
	if state == DEAD:
		get_tree().reload_current_scene()

func set_boss_health(val):
	$BossHealth.value = val


func _process(delta):
	
	if health == 0:
		state = DEAD
		fade_to_black()
	
	$Health.rect_size.x = 100 * health
	if health == 0:
		$Health.visible = false
	if fading:
		$FadeToBlack.modulate.a += delta / 2
		#$BGM.volume_db -= delta * 10
		Globals.camera.zoom = lerp(Globals.camera.zoom, Vector2(1.5,1.5), delta)
		if $FadeToBlack.modulate.a >= 1.5:
			on_faded()
	else:
		if Input.is_action_just_pressed('pause'):
			get_tree().paused = not get_tree().paused
			#$PauseSound.play()
			# Make buttons visible / invisible
		$FadeToBlack.modulate.a = max(0,$FadeToBlack.modulate.a - delta / 2)
		if get_tree().paused:
			pass
			# show pause screen
		else:
			pass
			# un show pause screen
