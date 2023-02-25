extends Area2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var player_in = false
export var enabled = false
export var level = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	Globals.portal = self
	$CollisionShape2D.disabled = true
	$Text.visible = false
	
	$Sprite.modulate.a = 0



func enable():
	enabled = true
	$FocusTimer.start()
	

func _process(delta):
	
	if enabled:
		$CollisionShape2D.disabled = false
		$Sprite.modulate.a += delta
		if not $FocusTimer.is_stopped():
			
			Globals.camera.move_to(global_position)
	
	
		
	if enabled and player_in:
		$Text.visible = true
	else:
		$Text.visible = false
	
	if enabled and player_in and Input.is_action_just_pressed("interact"):
		Globals.ui.transition_scene(level)
		$Sound.play()

func _on_Node2D_body_entered(body):
	if body == Globals.player:
		player_in = true


func _on_Node2D_body_exited(body):
	if body == Globals.player:
		player_in = false


func _on_FocusTimer_timeout():
	Globals.camera.return_to_player()
	pass
