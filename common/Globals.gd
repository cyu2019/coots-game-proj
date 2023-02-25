extends Node



var player
var ui
var enemy1
var camera

var portal
var cur_enemy

func frameFreeze(timeScale, duration):
	Engine.time_scale = timeScale
	yield(get_tree().create_timer(duration * timeScale), "timeout")
	Engine.time_scale = 1.0
