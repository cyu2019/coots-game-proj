extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var black

var fade_out = false
var fade_in = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	OS.window_maximized = true
	
	black = $UI.get_node("Black")
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Camera2D.zoom.x = 1920 / get_viewport().size.x
	$Camera2D.zoom.y = 1080 / get_viewport().size.y
	$Camera2D.position = lerp($Camera2D.position, Vector2.ZERO, delta)
	if fade_in:
		black.modulate.a -= delta
		if black.modulate.a <= 0:
			fade_in = false
			black.visible = false
	elif fade_out:
		black.modulate.a += delta
		if black.modulate.a >= 1.5:
			get_tree().change_scene("res://levels/test_slime.tscn")  
func _on_Button_pressed():
	fade_out = true
	black.visible = true
	fade_in = false
