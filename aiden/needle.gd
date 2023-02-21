extends Area2D


export var SPEED = 0.1
export var dir = Vector2.RIGHT

func _physics_process(delta):
	global_position += SPEED * dir * delta

func destroy():
	queue_free()



func _on_Needle_area_entered(area):
	destroy() # Replace with function body.


func _on_Needle_body_entered(body):
	destroy() # Replace with function body.


func _on_VisibilityNotifier2D_screen_exited():
	destroy() # Replace with function body.
