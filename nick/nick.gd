extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 3500
const jump_speed = 300

const KICK_SPEED = 1300

const ATTACK_HEIGHT = 300
const MAX_HEALTH = 30

const radius = 50

const shake_amount = 10
# ========================

export(PackedScene) var LASER = preload("res://nick/laser.tscn")

enum GAME_STATE {IDLE, 
				 POOF_WINDUP, POOF, 
				 LASER_SHOOT_WINDUP, LASER_SHOOT, 
				 LAND}
var state = GAME_STATE.IDLE

var velocity
var snap
var was_on_floor = true

var enemies_in_hurtbox = []
var is_invincible = false

var target_position = Vector2(0,0)

var x_dir_to_player


var health = MAX_HEALTH


# called on node beginning
func _ready():
	Globals.enemy1 = self
	velocity = Vector2.ZERO


func die():
	queue_free()

func hurt(damage = 1):
	health -= damage
	print(health)
	$ShakeTimer.start()
	
	if health == floor(MAX_HEALTH / 3.0):
		#$WindupTimer.wait_time = 0.5
		$ActionTimer.wait_time = 2
	
	if health <= 0:
		die()
	
func _on_HurtBox_body_entered(body):
	if not body in enemies_in_hurtbox:
		enemies_in_hurtbox.append(body)
func _on_HurtBox_body_exited(body):
	var i = enemies_in_hurtbox.find(body)
	if i > -1:
		enemies_in_hurtbox.remove(i)

func face_player():
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	x_dir_to_player = dir_to_player.x if dir_to_player.x != 0 else 1
	$AnimatedSprite.flip_h = true if dir_to_player.x < 0 else false

# called every frame
func _process(delta):	
	
	if not $ShakeTimer.is_stopped():
		$AnimatedSprite.offset = Vector2(rand_range(-shake_amount, shake_amount), rand_range(-shake_amount, shake_amount))
	else:
		$AnimatedSprite.offset = Vector2.ZERO
	
	# handles falling to their death
	if global_position.y > 5000:
		hurt()
	
	# if there is ground within this vector it will stick the player to the ground so they can walk down slopes
	# see move_and_slide_with_snap
	snap = Vector2.DOWN * 16
	
	if state == GAME_STATE.IDLE:
		# Need particles for poof later
		# $FireParticles.emitting = false
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.LASER_SHOOT_WINDUP:
		$AnimatedSprite.play("laser_shoot_windup")
	elif state == GAME_STATE.LASER_SHOOT:
		$AnimatedSprite.play("laser_shoot")
		# move to the position
		global_position = target_position
		# face the player
		face_player()
		shoot_laser()

		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		process_movement_gravity(delta)

	elif state == GAME_STATE.LAND:
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	
func process_movement_gravity(delta):
	velocity.y += gravity * delta
	process_movement(delta)

func process_movement(delta):
	if $FloorCast.is_colliding():
		velocity.y = 0
	move_and_slide_with_snap(velocity, snap, Vector2.UP)

# action timer
func _on_ActionTimer_timeout():
	if state == GAME_STATE.IDLE:
		var choice = randi() % 4
		# At the moment, these corners are fixed position
		# Maybe make it a random fixed distance from the player?

		# poof to bottom left corner, then throw needle at player
		if choice == 0:
			begin_shoot()
		# poof to bottom right corner, then throw needle at player
		elif choice == 1:
			begin_shoot()
		# poof to top right corner, then throw needle at player
		elif choice == 2:
			begin_shoot()
		# poof to top left corner, then throw needle at player
		else:
			begin_shoot()

# state transition functions
func begin_shoot():
	state = GAME_STATE.LASER_SHOOT
	target_position = position
	$WindupTimer.start()

func shoot_laser():
	var laser = LASER.instance()
	# print(get_tree().current_scene)
	get_tree().current_scene.add_child(laser)
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	laser.global_position = self.global_position + dir_to_player * 300
	laser.rotation = dir_to_player.angle()
	laser.dir = dir_to_player


# event handlers for state transitions
func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.LASER_SHOOT_WINDUP:
		state = GAME_STATE.LASER_SHOOT
