extends CanvasLayer


var health = 9
export var level = 0
var BGM

var next_scene

enum {FADE_IN, INTRO, DEFAULT, DEAD, DIALOGUE
	  DEFEATED_BOSS, TRANSITION_TO_NEXT_SCENE, DEFEATED_BOSS_ENDING}
var state = FADE_IN

# Text dialogue
var scene_text_file = "res://dialogue/slime.json"
var scene_text = {}
var selected_text = []
var in_progress = false
onready var firstbackground = $FirstDialogue/Background
# onready var secondbackground = $SecondDialogue/Background
onready var firsttext = $FirstDialogue/MainDialogue
# onready var secondtext = $SecondDialogue/SecondaryDialogue


# Called when the node enters the scene tree for the first time.
func _ready():
	$BossHealth.visible = false
	$BossName.visible = false
	if level == 0:
		scene_text_file = "res://dialogue/slime.json"
		BGM = $BGM
	elif level == 1:
		scene_text_file = "res://dialogue/aiden.json"
		BGM = $BGM2
	elif level == 2:
		scene_text_file = "res://dialogue/nick.json"
		BGM = $BGM3
	else:
		BGM = $BGM
	start()
	print(level)
	if level < 3:
		state = FADE_IN
		$FadeToBlack.visible = true
		$FadeToBlack.modulate.a = 1
		Globals.camera.zoom = Vector2(0.3,0.3)
	else:
		state = DEFAULT
		Globals.player.state = Globals.player.GAME_STATE.MOVEMENT
		Globals.camera.zoom = Vector2(1,1)
		Globals.camera.return_to_player()
	$BossHealth.value = 100
	Globals.ui = self
	Globals.player.connect("health_changed", self, "_on_health_change")
	OS.window_maximized = true
func _on_health_change(amt):
	health += amt
	
	if amt < 0:
		$HurtVignette.modulate.a = 1

func clean_tree():
	var instanced_nodes = get_tree().get_nodes_in_group("instanced")
	for node in instanced_nodes:
		node.queue_free()
		

func transition_scene(scene):
	next_scene = scene
	state = TRANSITION_TO_NEXT_SCENE
	
func on_faded():
	if state == DEAD:
		clean_tree()
		get_tree().reload_current_scene()
	elif state == TRANSITION_TO_NEXT_SCENE:
		clean_tree()
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
	
	if state == FADE_IN:
		process_fade_in(delta)
	elif state == INTRO:
		pass
	if state == DEFAULT:
		if $BossHealth.value == 0:
			state = DEFEATED_BOSS
		else:
			allow_pause(delta)
		
	elif state == DEAD:
		process_fade(delta)
	elif state == DEFEATED_BOSS:
		BGM.volume_db -= delta * 30
	elif state == TRANSITION_TO_NEXT_SCENE:
		process_fade(delta)
		BGM.volume_db -= delta * 30
	

func process_fade_in(delta):
	Globals.camera.zoom = Globals.camera.zoom.move_toward(Vector2(0.5,0.5), delta / 4)
	$FadeToBlack.modulate.a -= delta / 2
	if $FadeToBlack.modulate.a <= 0:
		#print("ba")
		state = INTRO
		$IntroTimer.start()
		$SecondarySubtitleTimer.start()
		
		$LabelHolder.visible = true
		if level == 0:
			scene_text_file = "res://dialogue/slime.json"
			$LabelHolder.get_node("Label1").visible = true
		elif level == 1:
			scene_text_file = "res://dialogue/aiden.json"
			$LabelHolder.get_node("Label2").visible = true
		elif level == 2:
			scene_text_file = "res://dialogue/nick.json"
			$LabelHolder.get_node("Label3").visible = true
		
		$IntroSting.play()
		$IntroSting2.play()
		Globals.camera.move_to(Globals.enemy1.global_position)
	
func process_fade(delta):
	
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

func play_death_sounds(level=0):
	$DeathSound.play()
	get_tree().paused = true
	start_text("End")
	if level == 0:
		$SlimeDeath.play()
	elif level == 1:
		$AidenDeath.play()
	elif level == 2:
		$NickDeath.play()

func play_phase_up_sound():
	$PhaseSound.play()



func _on_IntroTimer_timeout():
	state = DEFAULT
	Globals.player.state = Globals.player.GAME_STATE.MOVEMENT
	Globals.enemy1.state = Globals.enemy1.GAME_STATE.IDLE
	Globals.camera.zoom = Vector2(1,1)
	Globals.camera.return_to_player()
	
	$LabelHolder.visible = false
	$LabelHolder.get_node("Label1").visible = false
	$LabelHolder.get_node("Label2").visible = false
	$LabelHolder.get_node("Label3").visible = false
	$LabelHolder.get_node("SecondaryLabel1").visible = false
	$LabelHolder.get_node("SecondaryLabel2").visible = false
	$LabelHolder.get_node("SecondaryLabel3").visible = false
	$BossName.visible = true
	var name = ["SLIME", "AIDEN", "NICK"][level]
	$BossName.bbcode_text = "[center]%s[/center]" % (name)
	$BossHealth.visible = true
	
	get_tree().paused = false
	BGM.play()


func _on_SecondarySubtitleTimer_timeout():
	if level == 0:
		$LabelHolder.get_node("SecondaryLabel1").visible = true
	elif level == 1:
		$LabelHolder.get_node("SecondaryLabel2").visible = true
	elif level == 2:
		$LabelHolder.get_node("SecondaryLabel3").visible = true


################################################################################

func start():
	scene_text = load_scene_text()

func load_scene_text():
	var file = File.new()
	if file.file_exists(scene_text_file):
		file.open(scene_text_file, File.READ)
		return parse_json(file.get_as_text())

func next_line():
	if selected_text.size() > 0:
		push_line_to_main_dialogue()
	else:
		finish()

func finish():
	firsttext.text = ""
	firstbackground.visible = false
	in_progress = false
	get_tree().paused = false

func push_line_to_main_dialogue():
	firsttext.text = selected_text.pop_front()
	print(firsttext.text)

func start_text(text_key):
	if in_progress:
		next_line()
	else:
		get_tree().paused = true
		firstbackground.visible = true
		in_progress = true
		selected_text = scene_text[text_key].duplicate()
		push_line_to_main_dialogue()

# func push_line_to_secondary_dialogue(str):
