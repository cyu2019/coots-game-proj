extends Sprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


var target_position = Vector2(0,0)

# Called when the node enters the scene tree for the first time.
func _ready():
	modulate.a = 0
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	modulate.a = min(modulate.a + delta, 1)
	global_position = lerp(global_position, target_position, 5*delta)
	if target_position.x > 0:
		flip_h = true
