extends Sprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func _ready():
	pass

func flip(should_flip):
	flip_h = should_flip

func _process(delta):
	modulate.a -= delta * 2
	if modulate.a <= 0:
		queue_free()
