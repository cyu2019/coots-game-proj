extends Area2D


export var SPEED = 900
export var dir = Vector2.RIGHT

const IS_NEEDLE = true

const CROSS_IMPACT = preload("res://player/slash-impacts/cross_impact.tscn")

func _process(delta):
	global_position += SPEED * dir * delta

func destroy():
	spawn_impact()
	queue_free()
	#Globals.camera.shake(200,0.2)

func spawn_impact():
	var impact = CROSS_IMPACT.instance()
	impact.global_position = global_position
	get_tree().get_root().add_child(impact)
	impact.rotation = rand_range(-PI,PI)

func _on_Needle_area_entered(area):
	if area.name == "HurtBox" and "IS_PLAYER" in area.get_parent():
		area.get_parent().hurt()
	if "IS_NEEDLE" in area:
		return
	destroy() # Replace with function body.


func _on_Needle_body_entered(body):
	if "IS_ENEMY" in body:
		return
	destroy() # Replace with function body.


func _on_VisibilityNotifier2D_screen_exited():
	destroy() # Replace with function body.
