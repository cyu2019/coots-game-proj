extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 1000
const jump_speed = 300

const KICK_SPEED = 1300

const bl_corner = Vector2(-500, -50)
const br_corner = Vector2(500, -50)
const tr_corner = Vector2(500, -400)
const tl_corner = Vector2(-500, -400)

const SMOKE_PARTICLES_SCENE = preload("res://particles/SmokeParticles.tscn")
const smoke_trail_distance = 100


const ATTACK_HEIGHT = 300
const MAX_HEALTH = 30

const MAX_NEEDLES = 3



const radius = 50

const shake_amount = 10

var base_color = Color.white

# ========================

export(PackedScene) var NEEDLE = preload("res://aiden/needle.tscn")

enum GAME_STATE {IDLE, 
				 POOF, 
				 NEEDLE_THROW, 
				 NEEDLE_THROW_AIR,
				 NEEDLE_CHARGE,
				 NEEDLE_CHARGE_AIR,
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
	$AnimatedSprite.modulate = Color(100,100,100)
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
	$AnimatedSprite.modulate = $AnimatedSprite.modulate.linear_interpolate(base_color, delta * 20)
	
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
	elif state == GAME_STATE.POOF:
		$AnimatedSprite.play("poof")
		if $AnimatedSprite.frame == 4:
			var smoke = SMOKE_PARTICLES_SCENE.instance()
			smoke.global_position = global_position
			get_tree().get_root().add_child(smoke)
			
			
			var poof_dir = (target_position - global_position).normalized()
			var total_distance = target_position.distance_to(global_position)

			var cur_distance = smoke_trail_distance
			while cur_distance <= total_distance:
				var little_smoke = SMOKE_PARTICLES_SCENE.instance()
				little_smoke.global_position = global_position + poof_dir * cur_distance
				little_smoke.scale = Vector2(0.3, 0.3)
				get_tree().get_root().add_child(little_smoke)
				cur_distance += smoke_trail_distance
				
				
			
			
			
			# move to the position
			global_position = target_position
			var smoke2 = SMOKE_PARTICLES_SCENE.instance()
			smoke2.global_position = global_position
			get_tree().get_root().add_child(smoke2)
			# face the player
			face_player()
			# change to needle state, this one is in the air
			if global_position.y < -100:
				state = GAME_STATE.NEEDLE_CHARGE_AIR
				$WindupTimer.start()
				velocity.y = -400
			# otherwise we're on the ground
			else:
				state = GAME_STATE.NEEDLE_CHARGE
				$WindupTimer.start()

			# debugging
			# if $FloorCast.is_colliding():
			# 	state = GAME_STATE.LAND
			# process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_THROW:
		$AnimatedSprite.play("needle_throw")
		if $AnimatedSprite.frame >= 2 and num_needles < MAX_NEEDLES:
			throw_needle()
			num_needles += 1
		"""
		if num_needles >= MAX_NEEDLES and $AnimatedSprite.frame >= 4:
			state = GAME_STATE.LAND
		"""
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_CHARGE:
		$AnimatedSprite.play("needle_charge")
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_THROW_AIR:
		$AnimatedSprite.play("needle_throw_air")
		if $AnimatedSprite.frame >= 2 and num_needles < MAX_NEEDLES:
			throw_needle()
			num_needles += 1
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR:
		$AnimatedSprite.play("needle_charge_air")
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
			begin_poof(bl_corner)
			if global_position.x < 0:
				state = GAME_STATE.NEEDLE_CHARGE
				$WindupTimer.start()
		# poof to bottom right corner, then throw needle at player
		elif choice == 1:
			begin_poof(br_corner)
			if global_position.x > 0:
				state = GAME_STATE.NEEDLE_CHARGE
				$WindupTimer.start()
		# poof to top right corner, then throw needle at player
		elif choice == 2:
			begin_poof(tr_corner)
		# poof to top left corner, then throw needle at player
		else:
			begin_poof(tl_corner)

# state transition functions
func begin_poof(position):
	state = GAME_STATE.POOF
	target_position = position
	$WindupTimer.start()

func begin_needle_throw():
	state = GAME_STATE.NEEDLE_CHARGE
	$WindupTimer.start()

func begin_needle_air_throw():
	state = GAME_STATE.NEEDLE_CHARGE_AIR
	$WindupTimer.start()

func throw_needle():
	var needle = NEEDLE.instance()
	# print(get_tree().current_scene)
	get_tree().current_scene.add_child(needle)
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	needle.global_position = self.global_position + dir_to_player * 100 + dir_to_player.rotated(PI/2) * rand_range(-50, 50)
	needle.rotation = dir_to_player.angle()
	needle.dir = dir_to_player
	
	if is_on_floor():
		needle.dir.y = 0
	# print("direction")
	# print(dir_to_player)
	# print(needle.dir)
	# print(needle.global_position)

func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.NEEDLE_CHARGE:
		state = GAME_STATE.NEEDLE_THROW
		$WindupTimer.start()
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR:
		state = GAME_STATE.NEEDLE_THROW_AIR
	elif state == GAME_STATE.NEEDLE_THROW:
		state = GAME_STATE.IDLE
