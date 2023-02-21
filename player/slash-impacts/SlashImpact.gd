extends AnimatedSprite


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	scale *= rand_range(0.9,1.1)
	play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_straightimpact_animation_finished():
	queue_free()
	pass # Replace with function body.
