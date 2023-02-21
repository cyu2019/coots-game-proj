extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 3500
const jump_speed = 300

const KICK_SPEED = 1300

const STAGE_EDGE_X = 800
const ATTACK_HEIGHT = 300

"This is just so we don't have to hit it for a while, this can be tuned later"
const MAX_HEALTH = 30

const radius = 50

const shake_amount = 10

# ========================

# COMBO 1 = Falcon stomp
# COMBO 2 = Falcon kick air
# COMBO 3 = Falcon kick ground
enum GAME_STATE {IDLE, 
				 STOMP_WINDUP, STOMP, 
				 KICK_WINDUP, KICK, 
				 AIR_KICK_WINDUP, AIR_KICK, 
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

func hurt(damage=1):
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
	
	#was_on_floor = is_on_floor()
	
	# if there is ground within this vector it will stick the player to the ground so they can walk down slopes
	# see move_and_slide_with_snap
	snap = Vector2.DOWN * 16
	
	if state == GAME_STATE.IDLE:
		$FireParticles.emitting = false
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
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
		$FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		$FireParticles.emitting = true
		
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
		$FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		$FireParticles.emitting = true
		
		if $FloorCast.is_colliding():
			velocity.x = 0
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.3)
		process_movement(delta)
		
	elif state == GAME_STATE.LAND:
		$FireParticles.emitting = false
		$AnimatedSprite.play("land")
		process_movement_gravity(delta)
		
	
func process_movement_gravity(delta):
	velocity.y += gravity * delta
	process_movement(delta)

func process_movement(_delta):
	if $FloorCast.is_colliding():
		velocity.y = 0
	move_and_slide_with_snap(velocity, snap, Vector2.UP)

# action timer
func _on_ActionTimer_timeout():
	#Come up with better attack patterns
	if state == GAME_STATE.IDLE:
		
		var allowed_actions = 1
		if health <= floor(MAX_HEALTH / 3.0):
			allowed_actions = 3
		elif health <= floor(MAX_HEALTH * 2 / 3.0):
			allowed_actions = 2
		
		var choice = randi() % allowed_actions
		if choice == 0:
			begin_stomp()	
		elif choice == 1:
			begin_kick()
		else:
			begin_air_kick()

# state transition functions
func begin_stomp():
	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
	state = GAME_STATE.STOMP_WINDUP
	$WindupTimer.start()
func begin_kick():
	state = GAME_STATE.KICK_WINDUP
	face_player()
	$WindupTimer.start()
func begin_air_kick():
	state = GAME_STATE.AIR_KICK_WINDUP
	# var dir = 1
	# if rand_range(-1,1) >= 0:
	# 	dir = -1
	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
	$WindupTimer.start()
		
# event handlers for state transitions
func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "land" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.STOMP_WINDUP:
		state = GAME_STATE.STOMP
	elif state == GAME_STATE.KICK_WINDUP:
		$AnimatedSprite.play("kick")
		velocity.x = x_dir_to_player * KICK_SPEED
		state = GAME_STATE.KICK
		Globals.camera.shake(400,0.3)
	elif state == GAME_STATE.AIR_KICK_WINDUP:
		var kick_dir = (Globals.player.global_position - global_position).normalized()
		velocity = kick_dir * KICK_SPEED
		if abs(velocity.angle_to(Vector2.DOWN)) > PI/4:
			velocity = Vector2.DOWN.rotated(-sign(velocity.x) * PI/4) * KICK_SPEED
		Globals.camera.shake(400,0.3)
		state = GAME_STATE.AIR_KICK
		
