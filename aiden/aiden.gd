extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 3500
const jump_speed = 300

const KICK_SPEED = 1300

const bl_corner = Vector2(-400, -50)
const br_corner = Vector2(400, -50)
const tr_corner = Vector2(400, -400)
const tl_corner = Vector2(-400, -400)

const ATTACK_HEIGHT = 300
const MAX_HEALTH = 30

const MAX_NEEDLES = 3

const radius = 50

const shake_amount = 10
# ========================

export(PackedScene) var NEEDLE = preload("res://aiden/needle.tscn")

enum GAME_STATE {IDLE, 
				 POOF_WINDUP, POOF, 
				 NEEDLE_THROW_WINDUP, NEEDLE_THROW, 
				 NEEDLE_THROW_AIR_WINDUP, NEEDLE_THROW_AIR,
				 NEEDLE_CHARGE_WINDUP, NEEDLE_CHARGE,
				 NEEDLE_CHARGE_AIR_WINDUP, NEEDLE_CHARGE_AIR,
				 LAND}
var state = GAME_STATE.IDLE

var velocity
var snap
var was_on_floor = true

var num_needles = 0

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
"""
Main Idea:
Aiden will teleport around the stage, throw needles, then reset to the ground (if he ends up teleporting to the air)
"""
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
		num_needles = 0
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.POOF_WINDUP:
		$AnimatedSprite.play("poof_windup")
	elif state == GAME_STATE.POOF:
		$AnimatedSprite.play("poof")
		# move to the position
		global_position = target_position
		# face the player
		face_player()
		# change to needle state, this one is in the air
		if global_position.y < -100:
			begin_needle_air_charge()
		# otherwise we're on the ground
		else:
			begin_needle_charge()

		# debugging
		# if $FloorCast.is_colliding():
		# 	state = GAME_STATE.LAND
		# process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_THROW_WINDUP:
		$AnimatedSprite.play("needle_throw_windup")
	elif state == GAME_STATE.NEEDLE_THROW:
		$AnimatedSprite.play("needle_throw")
		if(num_needles < MAX_NEEDLES):
			throw_needle()
			num_needles += 1
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_CHARGE_WINDUP:
		$AnimatedSprite.play("needle_charge_windup")
	elif state == GAME_STATE.NEEDLE_CHARGE:
		$AnimatedSprite.play("needle_charge")
		state = GAME_STATE.NEEDLE_THROW_WINDUP

	elif state == GAME_STATE.NEEDLE_THROW_AIR_WINDUP:
		$AnimatedSprite.play("needle_throw_air_windup")
	elif state == GAME_STATE.NEEDLE_THROW_AIR:
		$AnimatedSprite.play("needle_throw_air")
		if(num_needles < MAX_NEEDLES):
			throw_needle()
			num_needles += 1
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR_WINDUP:
		$AnimatedSprite.play("needle_charge_air_windup")
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR:
		$AnimatedSprite.play("needle_charge_air")
		state = GAME_STATE.NEEDLE_THROW_AIR_WINDUP
	elif state == GAME_STATE.LAND:
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	"""
	elif state == GAME_STATE.STOMP_WINDUP:
		$AnimatedSprite.play("stomp_windup")
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.STOMP:
		$AnimatedSprite.play("stomp")
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.5)
		process_movement_gravity(delta)
	elif state == GAME_STATE.KICK_WINDUP:
		$AnimatedSprite.play("kick_windup")
	elif state == GAME_STATE.KICK:
		# $FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		# $FireParticles.emitting = true
		
		$AnimatedSprite.play("kick")
		var kick_dir = sign(velocity.x)
		if kick_dir < 0 and global_position.x <= -STAGE_EDGE_X or kick_dir > 0 and global_position.x > STAGE_EDGE_X:
			state = GAME_STATE.IDLE
			velocity.x = 0
		process_movement(delta)
	elif state == GAME_STATE.AIR_KICK_WINDUP:
		face_player()
		$AnimatedSprite.play("air_kick_windup")
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.AIR_KICK:
		$AnimatedSprite.play("air_kick")
		# $FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		# $FireParticles.emitting = true
		
		if $FloorCast.is_colliding():
			velocity.x = 0
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.3)
		process_movement(delta)
		
	elif state == GAME_STATE.LAND:
		# $FireParticles.emitting = false
		$AnimatedSprite.play("land")
		process_movement_gravity(delta)
	"""
	
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
			begin_poof(bl_corner)
		# poof to bottom right corner, then throw needle at player
		elif choice == 1:
			begin_poof(br_corner)
		# poof to top right corner, then throw needle at player
		elif choice == 2:
			begin_poof(tr_corner)
		# poof to top left corner, then throw needle at player
		else:
			begin_poof(tl_corner)

# state transition functions
func begin_poof(position):
	state = GAME_STATE.POOF_WINDUP
	target_position = position
	$WindupTimer.start()

func begin_needle_charge():
	state = GAME_STATE.NEEDLE_CHARGE_WINDUP
	$WindupTimer.start()

func begin_needle_air_charge():
	state = GAME_STATE.NEEDLE_CHARGE_AIR_WINDUP
	$WindupTimer.start()

func begin_needle_throw():
	state = GAME_STATE.NEEDLE_THROW_WINDUP
	$WindupTimer.start()

func begin_needle_air_throw():
	state = GAME_STATE.NEEDLE_THROW_AIR_WINDUP
	$WindupTimer.start()

func throw_needle():
	var needle = NEEDLE.instance()
	# print(get_tree().current_scene)
	get_tree().current_scene.add_child(needle)
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	needle.global_position = self.global_position + dir_to_player * 300
	needle.rotation = dir_to_player.angle()
	needle.dir = dir_to_player
	# print("direction")
	# print(dir_to_player)
	# print(needle.dir)
	# print(needle.global_position)

# func begin_stomp():
# 	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
# 	state = GAME_STATE.STOMP_WINDUP
# 	$WindupTimer.start()
# func begin_kick():
# 	state = GAME_STATE.KICK_WINDUP
# 	face_player()
# 	$WindupTimer.start()
# func begin_air_kick():
# 	state = GAME_STATE.AIR_KICK_WINDUP
# 	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
# 	$WindupTimer.start()
		
# event handlers for state transitions
func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.POOF_WINDUP:
		state = GAME_STATE.POOF
	elif state == GAME_STATE.NEEDLE_THROW_WINDUP:
		state = GAME_STATE.NEEDLE_THROW
	elif state == GAME_STATE.NEEDLE_THROW_AIR_WINDUP:
		state = GAME_STATE.NEEDLE_THROW_AIR
	elif state == GAME_STATE.NEEDLE_CHARGE_WINDUP:
		state = GAME_STATE.NEEDLE_CHARGE
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR_WINDUP:
		state = GAME_STATE.NEEDLE_CHARGE_AIR

	# if state == GAME_STATE.STOMP_WINDUP:
	# 	state = GAME_STATE.STOMP
	# elif state == GAME_STATE.KICK_WINDUP:
	# 	$AnimatedSprite.play("kick")
	# 	velocity.x = x_dir_to_player * KICK_SPEED
	# 	state = GAME_STATE.KICK
	# 	Globals.camera.shake(400,0.3)
	# elif state == GAME_STATE.AIR_KICK_WINDUP:
	# 	var kick_dir = (Globals.player.global_position - global_position).normalized()
	# 	velocity = kick_dir * KICK_SPEED
	# 	if abs(velocity.angle_to(Vector2.DOWN)) > PI/4:
	# 		velocity = Vector2.DOWN.rotated(-sign(velocity.x) * PI/4) * KICK_SPEED
	# 	Globals.camera.shake(400,0.3)
	# 	state = GAME_STATE.AIR_KICK
		
