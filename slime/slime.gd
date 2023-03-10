extends KinematicBody2D

const IS_ENEMY = true
const LAND_PARTICLES_SCENE = preload("res://particles/LandParticles.tscn")
const DEATH_PARTICLES_SCENE = preload("res://particles/DeathParticles.tscn")

# == numbers to tweak == 
const gravity = 3500
const jump_speed = 300

var KICK_SPEED = 1300

const STAGE_EDGE_X = 850
const ATTACK_HEIGHT = 500

const MAX_HEALTH = 50

const radius = 50

const shake_amount = 10

# collision box
# position: 0,0
# scale: 6,10

# ========================

# COMBO 1 = Falcon stomp
# COMBO 2 = Falcon kick air
# COMBO 3 = Falcon kick ground
enum GAME_STATE {INTRO, IDLE, 
				 STOMP_WINDUP, STOMP, 
				 KICK_WINDUP, KICK, 
				 AIR_KICK_WINDUP, AIR_KICK, 
				 LAND, DEAD}
onready var state = GAME_STATE.INTRO

var velocity
var snap
var was_on_floor = true

var enemies_in_hurtbox = []
var is_invincible = false

var target_position = Vector2(0,0)

var x_dir_to_player

var base_color = Color.white

var health = MAX_HEALTH


var burst_counter = 0
var burst_amt = 0

# called on node beginning
func _ready():
	$CollisionShape2D.position = Vector2(0,0)
	$CollisionShape2D.scale = Vector2(6,10)
	Globals.enemy1 = self
	velocity = Vector2.ZERO
	face_player()

func die():
	pause_mode = Node.PAUSE_MODE_PROCESS
	if is_instance_valid($CollisionShape2D):
		$CollisionShape2D.queue_free()
	Globals.ui.play_death_sounds(0)
	state = GAME_STATE.DEAD
	
	Globals.camera.shake(1000,1)
	Engine.time_scale = 1.0

	Globals.camera.move_to(global_position)
	get_tree().paused = true
	var particles = DEATH_PARTICLES_SCENE.instance()
	particles.global_position = global_position
	get_tree().get_root().add_child(particles)

func hurt(damage = 1):
	var prev_health = health
	health -= damage
	$AnimatedSprite.modulate = Color(100,100,100)
	$ShakeTimer.start()
	Globals.camera.shake(200,0.2)
	
	
	Globals.ui.set_boss_health(100 * health / MAX_HEALTH)

	# phase
	if health <= floor(MAX_HEALTH/3) and prev_health > floor(MAX_HEALTH/3):
		Globals.ui.play_phase_up_sound()
		$ActionTimer.wait_time = 0.5
		#KICK_SPEED = 1800
		base_color = Color.orangered
	elif health <= floor(MAX_HEALTH/3*2) and prev_health > floor(MAX_HEALTH/3*2):
		Globals.ui.play_phase_up_sound()
		$WindupTimer.wait_time = 0.8
		$ActionTimer.wait_time = 1
		#KICK_SPEED = 1600
		base_color = Color.orange
	
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
	x_dir_to_player = sign(dir_to_player.x) if dir_to_player.x != 0 else 1
	$AnimatedSprite.flip_h = true if dir_to_player.x < 0 else false

# called every frame
func _process(delta):	
	$AnimatedSprite.modulate = $AnimatedSprite.modulate.linear_interpolate(base_color, delta * 20)
	
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
	
	if state == GAME_STATE.INTRO:
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.IDLE:
		$CollisionShape2D.position = Vector2(0,0)
		$CollisionShape2D.scale = Vector2(6,10)
		$FireParticles.emitting = false
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.STOMP_WINDUP:
		$AnimatedSprite.play("stomp_windup")
		move_and_slide_with_snap(Vector2.ZERO, Vector2.ZERO, Vector2.UP)
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.STOMP:
		$AnimatedSprite.play("stomp")
		if is_on_floor():
			$CollisionShape2D.position = Vector2(5,10)
			$CollisionShape2D.scale = Vector2(7,8)
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.5)
			$RumbleSound.play()
			var particles = LAND_PARTICLES_SCENE.instance()
			particles.global_position = global_position + Vector2.DOWN * 80
			get_tree().get_root().add_child(particles)
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
			$ActionTimer.start()
		process_movement(delta)
	elif state == GAME_STATE.AIR_KICK_WINDUP:
		face_player()
		
		move_and_slide_with_snap(Vector2.ZERO, Vector2.ZERO, Vector2.UP)
		$AnimatedSprite.play("air_kick_windup")
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.AIR_KICK:
		$AnimatedSprite.play("air_kick")
		$FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		$FireParticles.emitting = true
		
		if is_on_floor():
			velocity.x = 0
			$CollisionShape2D.position = Vector2(5,10)
			$CollisionShape2D.scale = Vector2(7,8)
			state = GAME_STATE.LAND
			
			var particles = LAND_PARTICLES_SCENE.instance()
			particles.global_position = global_position + Vector2.DOWN * 80
			get_tree().get_root().add_child(particles)
			$RumbleSound.play()
			
			Globals.camera.shake(400,0.3)
		process_movement(delta)
		
	elif state == GAME_STATE.LAND:
		$FireParticles.emitting = false
		$AnimatedSprite.play("land")
		process_movement_gravity(delta)
	
	elif state == GAME_STATE.DEAD:
		modulate.a -= delta / 2
		if modulate.a <= 0:
			get_tree().paused = false
			queue_free()
			Globals.portal.enable()
			#get_tree().change_scene("res://levels/test_aiden.tscn")
	
func process_movement_gravity(delta):
	velocity.y += gravity * delta
	process_movement(delta)

func process_movement(_delta):
	if is_on_floor():
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
	$CollisionShape2D.position = Vector2(0,-20)
	$CollisionShape2D.scale = Vector2(6,8)
	target_position = Vector2(Globals.player.global_position.x, -ATTACK_HEIGHT)
	state = GAME_STATE.STOMP_WINDUP
	$WindupTimer.start()
func begin_kick():
	$CollisionShape2D.position = Vector2(-5,0)
	$CollisionShape2D.scale = Vector2(8,10)
	state = GAME_STATE.KICK_WINDUP
	face_player()
	$WindupTimer.start()
func begin_air_kick():
	$CollisionShape2D.position = Vector2(-5,0)
	$CollisionShape2D.scale = Vector2(8,10)
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
		$CollisionShape2D.position = Vector2(-10,-10)
		$CollisionShape2D.scale = Vector2(8,10)
		state = GAME_STATE.STOMP
		$StompCry.play()
	elif state == GAME_STATE.KICK_WINDUP:
		$CollisionShape2D.position = Vector2(20,-15)
		$CollisionShape2D.scale = Vector2(11,7.5)
		velocity.x = x_dir_to_player * KICK_SPEED
		state = GAME_STATE.KICK
		Globals.camera.shake(400,0.3)
		$RumbleSound.play()
		$KickTimer.start()
		$FalconKickSound.play()
		$FireSound.play()
	elif state == GAME_STATE.AIR_KICK_WINDUP:
		var kick_dir = (Globals.player.global_position - global_position).normalized()
		velocity = kick_dir * KICK_SPEED
		if abs(velocity.angle_to(Vector2.DOWN)) > PI/4:
			velocity = Vector2.DOWN.rotated(-sign(velocity.x) * PI/4) * KICK_SPEED
		Globals.camera.shake(400,0.3)
		$RumbleSound.play()
		$CollisionShape2D.position = Vector2(5,30)
		$CollisionShape2D.scale = Vector2(8,10)
		state = GAME_STATE.AIR_KICK
		$FalconKickSound.play()
		$FireSound.play()
		
func _on_KickTimer_timeout():
	if state == GAME_STATE.KICK:
		state = GAME_STATE.IDLE
		velocity.x = 0
		$ActionTimer.start()
