extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
const IS_ENEMY = true

func _ready():
	pass

func flip(should_flip):
	$Sprite.flip_h = should_flip

func _process(delta):
	$Sprite.modulate.a -= delta * 5
	if $Sprite.modulate.a <= 0:
		queue_free()
