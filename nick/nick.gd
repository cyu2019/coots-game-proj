extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 1500
const MAX_HEALTH = 30
const DASH_AMOUNT = 500
const UPB_SPEED = 1000
const ATTACK_HEIGHT = 300
const radius = 50
const shake_amount = 10
const STAGE_EDGE_X = 600
var base_color = Color.white

# ========================
export(PackedScene) var LASER = preload("res://nick/laser.tscn")
enum GAME_STATE {IDLE, 
				 SIDEB_WINDUP, 
				 SIDEB, 
				 UPB_CHARGE,
				 UPB,
				 LASER,
				 LASER_WINDUP,
				 LAND}
var state = GAME_STATE.IDLE
var velocity
var snap
var num_lasers
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
	$AnimatedSprite.modulate = Color(100,100,100)
	$ShakeTimer.start()
	
	if health == floor(MAX_HEALTH / 2.0):
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
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.SIDEB_WINDUP:
		face_player()
	elif state == GAME_STATE.SIDEB:
		$AnimatedSprite.play("sideb")
		# if $AnimatedSprite.frame == 1:
		# come back to this and make a teleport + trail of nicks
		global_position = lerp(global_position, global_position + DASH_AMOUNT * Vector2(x_dir_to_player,0), delta * 5)
		process_movement_gravity(delta)
	elif state == GAME_STATE.UPB_CHARGE:
		$AnimatedSprite.play("upb_charge")
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.UPB:
		$AnimatedSprite.play("upb")
		$FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		$FireParticles.emitting = true
		var rot = rotation
		rotation = 0
		if $FloorCast.is_colliding():
			velocity.x = 0
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.3)
		var kick_dir = sign(velocity.x)
		if kick_dir < 0 and global_position.x <= -STAGE_EDGE_X or kick_dir > 0 and global_position.x > STAGE_EDGE_X:
			state = GAME_STATE.IDLE
			velocity.x = 0
			$ActionTimer.start()
		process_movement(delta)
	elif state == GAME_STATE.LASER_WINDUP:
		# come back to this and fix projectiles to not spawn impact if you dash
		$AnimatedSprite.play("laser")
		if $AnimatedSprite.frame >= 4 and num_lasers == 0:
			shoot_laser()
			num_lasers += 1
	elif state == GAME_STATE.LASER:
		$AnimatedSprite.play("laser")
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		process_movement_gravity(delta)
	elif state == GAME_STATE.LAND:
		$FireParticles.emitting = false
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
		var allowed_actions = 1
		if health <= floor(MAX_HEALTH * 2 / 3.0):
			allowed_actions = 2
		elif health <= floor(MAX_HEALTH / 3.0):
			allowed_actions = 3
		var choice = randi() % allowed_actions
		if choice == 0:
			begin_upb()	
		elif choice == 1:
			begin_upb()
		else:
			begin_upb()

# state transition functions
func begin_laser():
	num_lasers = 0
	state = GAME_STATE.LASER_WINDUP
	$WindupTimer.start()

func begin_sideb():
	state = GAME_STATE.SIDEB_WINDUP
	$WindupTimer.start()

func begin_upb():
	state = GAME_STATE.UPB_CHARGE
	face_player()
	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
	$WindupTimer.start()

func shoot_laser():
	var laser = LASER.instance()
	get_tree().current_scene.add_child(laser)
	face_player()
	var dir_to_player = Vector2(x_dir_to_player, 0)
	laser.global_position = self.global_position + dir_to_player * 100
	laser.rotation = dir_to_player.angle()
	laser.dir = dir_to_player

func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.UPB_CHARGE:
		var upb_dir = (Globals.player.global_position - global_position).normalized()
		velocity = upb_dir * UPB_SPEED
		print(velocity)
		rotation = velocity.angle() + PI/2
		print(rotation)
		Globals.camera.shake(400,0.3)
		state = GAME_STATE.UPB
	elif state == GAME_STATE.SIDEB_WINDUP:
		state = GAME_STATE.SIDEB
		$WindupTimer.start()
	elif state == GAME_STATE.LASER_WINDUP:
		state = GAME_STATE.LASER
	elif state == GAME_STATE.LASER:
		if $FloorCast.is_colliding():
			state = GAME_STATE.IDLE
		else:
			num_lasers = 0
			state = GAME_STATE.LASER_WINDUP
			$WindupTimer.start()
	elif state == GAME_STATE.SIDEB:
		state = GAME_STATE.IDLE
