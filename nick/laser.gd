extends Area2D


export var SPEED = 1000
export var dir = Vector2.RIGHT

const IS_LASER = true

const CROSS_IMPACT = preload("res://player/slash-impacts/cross_impact.tscn")

func _process(delta):
	global_position += SPEED * dir * delta

func destroy(check):
	if(check):
		spawn_impact()
	queue_free()
	#Globals.camera.shake(200,0.2)

func spawn_impact():
	var impact = CROSS_IMPACT.instance()
	impact.global_position = global_position
	impact.modulate = Color.red
	get_tree().get_root().add_child(impact)
	impact.rotation = rand_range(-PI,PI)

func _on_Needle_area_entered(area):
	print(area.get_parent())
	if area.name == "HurtBox" and "IS_PLAYER" in area.get_parent():
		if Globals.player.state == Globals.player.GAME_STATE.DASH:
			return
		area.get_parent().hurt()		
		destroy(true)
		return
	if "IS_LASER" in area:
		return
	destroy(true) # Replace with function body.


func _on_Needle_body_entered(body):
	if "IS_ENEMY" in body:
		return
	destroy(true) # Replace with function body.


func _on_VisibilityNotifier2D_screen_exited():
	destroy(true) # Replace with function body.
