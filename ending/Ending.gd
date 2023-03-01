extends CanvasLayer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var black

var fade_out = false
var fade_in = true

# Called when the node enters the scene tree for the first time.
func _ready():
	
	black = $Black
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if fade_in:
		print("fading in")
		black.modulate.a -= delta
		if black.modulate.a <= 0:
			fade_in = false
			black.visible = false
	elif fade_out:
		$BGM.volume_db -= 40*delta
		black.modulate.a += delta
		if black.modulate.a >= 1.5:
			get_tree().change_scene("res:///title-screen/title.tscn")  
func _on_Button_pressed():
	fade_out = true
	black.visible = true
	fade_in = false
