extends KinematicBody2D



const LAND_PARTICLES_SCENE = preload("res://particles/LandParticles.tscn")
const DEATH_PARTICLES_SCENE = preload("res://particles/DeathParticles.tscn")

const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 1500
# sideb
const DASH_AMOUNT = 500
const NICK_AFTER_IMAGE = preload("res://nick/after_image.tscn")
const after_image_distance = 100
const STAGE_EDGE_X = 900
# upb
const UPB_SPEED = 1000
const ATTACK_HEIGHT = 300
const MAX_DIST = 500
# camera and character
const MAX_HEALTH = 30
const shake_amount = 10
var base_color = Color.white

# collision box
# position: 3, 0
# scale: 7, 10

# ========================
var LASER = preload("res://nick/laser.tscn")
enum GAME_STATE {IDLE, 
				 SIDEB, 
				 UPB_CHARGE,
				 UPB,
				 LASER,
				 LASER_WINDUP,
				 LAND,
				DEAD}
var state = GAME_STATE.IDLE
var velocity
var snap
var num_lasers
var dist_travelled = 0
var was_on_floor = true
var enemies_in_hurtbox = []
var is_invincible = false
var target_position = Vector2(0,0)
var x_dir_to_player
var health = MAX_HEALTH

# === combat vars
var burst_counter = 0
var burst_amt = 0

# called on node beginning
func _ready():
	$CollisionShape2D.position = Vector2(3,0)
	$CollisionShape2D.scale = Vector2(7,10)
	Globals.enemy1 = self
	velocity = Vector2.ZERO

func die():
	pause_mode = Node.PAUSE_MODE_PROCESS
	$CollisionShape2D.queue_free()
	state = GAME_STATE.DEAD
	Globals.camera.global_position = global_position
	get_tree().paused = true
	
	Engine.time_scale = 1.0
	#queue_free()
	var particles = DEATH_PARTICLES_SCENE.instance()
	particles.global_position = global_position
	get_tree().get_root().add_child(particles)

func hurt(damage = 1):
	health -= damage
	$AnimatedSprite.modulate = Color(100,100,100)
	$ShakeTimer.start()
	Globals.ui.set_boss_health(100 * health / MAX_HEALTH)
	
	if health <= floor(MAX_HEALTH):
		base_color = Color.purple
		burst_amt = 3
		$ActionTimer.wait_time = 1.5
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
		$CollisionShape2D.position = Vector2(3,0)
		$CollisionShape2D.scale = Vector2(7,10)
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.SIDEB:
		$AnimatedSprite.play("sideb")

	elif state == GAME_STATE.UPB_CHARGE:
		$AnimatedSprite.play("upb_charge")
		$FireParticles.emitting = true
		$FireParticles.rotation = 0
		global_position = lerp(global_position, target_position, delta * 5)
	elif state == GAME_STATE.UPB:
		$AnimatedSprite.play("upb")
		$FireParticles.rotation = Vector2.DOWN.angle_to(velocity)
		$FireParticles.emitting = true
		# starts in the air and goes to ground
		if $FloorCast.is_colliding() and target_position.y < -100:
			$AnimatedSprite.rotation = 0
			$CollisionShape2D.rotation = 0
			velocity.x = 0
			state = GAME_STATE.LAND
			Globals.camera.shake(400,0.3)
			if burst_counter > 0:
				burst_counter -= 1
				begin_upb()
			else:
				state = GAME_STATE.LAND
		elif dist_travelled >= MAX_DIST:
			$AnimatedSprite.rotation = 0
			$CollisionShape2D.rotation = 0
			velocity.x = 0
			if burst_counter > 0:
				burst_counter -= 1
				begin_upb()
			else:
				state = GAME_STATE.LAND
		# var kick_dir = sign(velocity.x)
		# if kick_dir < 0 and global_position.x <= -STAGE_EDGE_X or kick_dir > 0 and global_position.x > STAGE_EDGE_X:
		# 	state = GAME_STATE.IDLE
		# 	velocity.x = 0
		# 	$ActionTimer.start()
		dist_travelled += delta * velocity.length()
		move_and_slide_with_snap(velocity, Vector2(0,0), Vector2.UP)
	elif state == GAME_STATE.LASER_WINDUP:
		$AnimatedSprite.play("laser_windup")
		process_movement_gravity(delta)
	elif state == GAME_STATE.LASER:
		$AnimatedSprite.play("laser")
		process_movement_gravity(delta)
	elif state == GAME_STATE.LAND:
		$FireParticles.emitting = false
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.DEAD:
		modulate.a -= delta
		if modulate.a <= 0:
			Globals.camera.position = Vector2(0,0)
			get_tree().paused = false
			queue_free()
	
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
		burst_counter = burst_amt
		var num_actions = 3
		var choice = randi() % num_actions
		if choice == 0:
			begin_sideb()
		elif choice == 1:
			begin_upb()
		else:
			begin_laser()

# state transition functions
func begin_laser():
	$CollisionShape2D.position = Vector2(3,0)
	$CollisionShape2D.scale = Vector2(6,9)
	num_lasers = 0
	state = GAME_STATE.LASER_WINDUP
	$WindupTimer.start()

func begin_sideb():
	$CollisionShape2D.position = Vector2(3,25)
	$CollisionShape2D.scale = Vector2(8,7)
	state = GAME_STATE.SIDEB
	face_player()
	var dir_to_player = Vector2(-1 if $AnimatedSprite.flip_h else 1, 0)
	target_position = global_position + dir_to_player * DASH_AMOUNT
	if target_position.x < -STAGE_EDGE_X:
		target_position.x = -STAGE_EDGE_X
	elif target_position.x > STAGE_EDGE_X:
		target_position.x = STAGE_EDGE_X
	$WindupTimer.start()

func begin_upb():
	$CollisionShape2D.position = Vector2(3,0)
	$CollisionShape2D.scale = Vector2(6,10)
	state = GAME_STATE.UPB_CHARGE
	face_player()
	dist_travelled = 0
	target_position = global_position
	$WindupTimer.start()

func shoot_laser():
	$ShakeTimer.start()
	var laser = LASER.instance()
	get_tree().current_scene.add_child(laser)
	face_player()
	var dir_to_player = Vector2(-1 if $AnimatedSprite.flip_h else 1, 0)
	laser.global_position = self.global_position + dir_to_player * 100
	laser.rotation = dir_to_player.angle()
	laser.dir = dir_to_player

func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.UPB_CHARGE:
		$CollisionShape2D.position = Vector2(-15,0)
		$CollisionShape2D.scale = Vector2(5,10)
		var upb_dir = (Globals.player.global_position - global_position).normalized()
		velocity = upb_dir * UPB_SPEED
		if velocity.length() == 0:
			velocity = Vector2.RIGHT * UPB_SPEED
		$AnimatedSprite.rotation = velocity.angle() + PI/2
		$CollisionShape2D.rotation = velocity.angle() + PI/2
		Globals.camera.shake(400,0.3)
		state = GAME_STATE.UPB
	elif state == GAME_STATE.LASER_WINDUP:
		state = GAME_STATE.LASER
		shoot_laser()
		$WindDownTimer.start()
	elif state == GAME_STATE.SIDEB:
		var after_image = NICK_AFTER_IMAGE.instance()
		after_image.global_position = global_position
		after_image.flip($AnimatedSprite.flip_h)
		get_tree().get_root().add_child(after_image)

		var dash_dir = (target_position - global_position).normalized()
		var total_distance = target_position.distance_to(global_position)

		var cur_distance = after_image_distance
		while cur_distance <= total_distance:
			var after = NICK_AFTER_IMAGE.instance()
			after.global_position = global_position + dash_dir * cur_distance
			after.modulate.a = 1 - cur_distance / total_distance
			after.flip($AnimatedSprite.flip_h)
			get_tree().get_root().add_child(after)
			cur_distance += after_image_distance
		# move to the position
		global_position = target_position
		face_player()
		if global_position.y < -100:
			begin_upb()
		else:
			velocity.x = 0
			if burst_counter > 0:
				burst_counter -= 1
				begin_sideb()
			else:
				$WindDownTimer.start()
				$ShakeTimer.start()
		
func _on_WindDownTimer_timeout():
	state = GAME_STATE.IDLE
