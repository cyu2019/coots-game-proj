extends Area2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


const OFFSET_AMOUNT = 125

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimatedSprite.play()
	pass # Replace with function body.

"""
#unused, if we want slash to not be stuck to the player
func init(pos, offset_dir):
	global_position = pos + offset_dir * OFFSET_AMOUNT
	var angle = Vector2.RIGHT.angle_to(offset_dir) 
	$AnimatedSprite.rotation = angle
	$CollisionShape2D.rotation = angle
"""
	
func init(offset_dir):
	transform.origin = offset_dir * OFFSET_AMOUNT
	var angle = Vector2.RIGHT.angle_to(offset_dir) 
	$AnimatedSprite.rotation = angle
	$CollisionShape2D.rotation = angle

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_AnimatedSprite_animation_finished():
	queue_free()
	pass # Replace with function body.
