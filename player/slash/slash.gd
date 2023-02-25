extends Area2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const STRAIGHT_IMPACT_SCENE = preload("res://player/slash-impacts/straight_impact.tscn")
const CROSS_IMPACT_SCENE = preload("res://player/slash-impacts/cross_impact.tscn")

const PUSHBACK = Vector2(15000, 600)
const OFFSET_AMOUNT = 125

var hit = []
var hit_dir

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimatedSprite.play()
	$WooshSound.play()
	pass # Replace with function body.

"""
#unused, if we want slash to not be stuck to  the player
func init(pos, offset_dir):
	global_position = pos + offset_dir * OFFSET_AMOUNT
	var angle = Vector2.RIGHT.angle_to(offset_dir) 
	$AnimatedSprite.rotation = angle
	$CollisionShape2D.rotation = angle
"""
	
func init(offset_dir):
	transform.origin = offset_dir * OFFSET_AMOUNT
	hit_dir = offset_dir
	var angle = Vector2.RIGHT.angle_to(offset_dir) 
	$AnimatedSprite.rotation = angle
	$CollisionShape2D.rotation = angle

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_AnimatedSprite_animation_finished():
	queue_free()
	pass # Replace with function body.


func _on_Slash_body_entered(body):
	if body in hit:
		return
		
	if "IS_ENEMY" in body and body.has_method('hurt'):
		
		Globals.frameFreeze(0.05, 0.4)
		body.hurt()
		$HitSound.play()
		var impact1 = STRAIGHT_IMPACT_SCENE.instance()
		var impact2 = CROSS_IMPACT_SCENE.instance()
		impact1.global_position = body.global_position
		impact2.global_position = body.global_position
		impact1.rotation = $AnimatedSprite.rotation + rand_range(-0.5,0.5)
		impact2.rotation = $AnimatedSprite.rotation + PI/2 + rand_range(-0.5,0.5)
		get_tree().get_root().add_child(impact1)
		get_tree().get_root().add_child(impact2)
		
		hit.append(body)
		
		if -hit_dir.x != 0:
			get_parent().velocity.x = (PUSHBACK * -hit_dir).x
		elif -hit_dir.y != 0:
			get_parent().velocity.y = (PUSHBACK * -hit_dir).y
