extends TextureRect


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _process(delta):
	rect_scale.x = get_viewport_rect().size.x / rect_size.x
	rect_scale.y = get_viewport_rect().size.y / rect_size.y
