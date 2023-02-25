extends CanvasLayer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var health = 8
export var level = 0
var BGM


var next_scene

enum {INTRO, DEFAULT, DEAD, DEFEATED_BOSS, TRANSITION_TO_NEXT_SCENE, DEFEATED_BOSS_ENDING}
var state = DEFAULT
# Called when the node enters the scene tree for the first time.
func _ready():
	print (level)
	if level == 0:
		BGM = $BGM
	elif level == 1:
		BGM = $BGM2
	else:
		BGM = $BGM3
	
	BGM.play()	
		
	
	Globals.ui = self
	$FadeToBlack.visible = true
	$BossHealth.value = 100
	Globals.player.connect("health_changed", self, "_on_health_change")
	get_tree().paused = false
	OS.window_maximized = true
func _on_health_change(amt):
	health += amt
	
	if amt < 0:
		$HurtVignette.modulate.a = 1

func transition_scene(scene):
	next_scene = scene
	state = TRANSITION_TO_NEXT_SCENE
	
func on_faded():
	if state == DEAD:
		get_tree().reload_current_scene()
	elif state == TRANSITION_TO_NEXT_SCENE:
		get_tree().change_scene(next_scene)

func set_boss_health(val):
	$BossHealth.value = val

func _process(delta):
	$Health.rect_size.x = 100 * health
	if health == 0:
		$Health.visible = false
		state = DEAD
		get_tree().paused = true
	else:
		$HurtVignette.modulate.a -= delta	
	
	
	if state == DEFAULT:
		
		if $BossHealth.value == 0:
			state = DEFEATED_BOSS
		else:
			allow_pause(delta)
		
	elif state == DEAD:
		process_fade(delta)
	elif state == DEFEATED_BOSS:
		print ('bbbb')
		BGM.volume_db -= delta * 30
	elif state == TRANSITION_TO_NEXT_SCENE:
		process_fade(delta)
		BGM.volume_db -= delta * 30
		
	
func process_fade(delta):
	print("baaaaa")
	$FadeToBlack.modulate.a += delta / 2
	$BGM.volume_db -= delta * 10
	Globals.camera.zoom = lerp(Globals.camera.zoom, Vector2(0.5,0.5), delta)
	if $FadeToBlack.modulate.a >= 1.5:
		on_faded()

func allow_pause(delta):
	if Input.is_action_just_pressed('pause'):
		get_tree().paused = not get_tree().paused
		#$PauseSound.play()
		# Make buttons visible / invisible
	$FadeToBlack.modulate.a = max(0,$FadeToBlack.modulate.a - delta / 2)
	if get_tree().paused:
		$PauseMenu.visible = true
	else:
		$PauseMenu.visible = false
		
