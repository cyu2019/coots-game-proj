extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.ui.push_line_to_secondary_dialogue("Ludwig has been kidnapped by the members of the yard!")
	Globals.ui.push_line_to_secondary_dialogue("(He probably deserved it...)")
	Globals.ui.push_line_to_secondary_dialogue("You're our only hope...")
	Globals.ui.push_line_to_secondary_dialogue("Coots in boots...!!!!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Timer_timeout():
	Globals.portal.enable()
