extends Sprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var seen = false
# Called when the node enters the scene tree for the first time.
func _ready():
	modulate.a = 0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	modulate.a = min(modulate.a + delta, 1)	


