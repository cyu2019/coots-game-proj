extends KinematicBody2D


const IS_ENEMY = true

# == numbers to tweak == 
const gravity = 1000
const bl_corner = Vector2(-500, -50)
const br_corner = Vector2(500, -50)
const tr_corner = Vector2(500, -400)
const tl_corner = Vector2(-500, -400)
const SMOKE_PARTICLES_SCENE = preload("res://particles/SmokeParticles.tscn")
const DEATH_PARTICLES_SCENE = preload("res://particles/DeathParticles.tscn")
const smoke_trail_distance = 100
const MAX_HEALTH = 50
const MAX_NEEDLES = 3
const shake_amount = 10
var base_color = Color.white

# collision box
# position: -3, 13.25
# scale: 5, 8

# ========================

export(PackedScene) var NEEDLE = preload("res://aiden/needle.tscn")
enum GAME_STATE {IDLE, 
				 POOF, 
				 NEEDLE_THROW, 
				 NEEDLE_THROW_AIR,
				 NEEDLE_CHARGE,
				 NEEDLE_CHARGE_AIR,
				 LAND,
				DEAD}
var state = GAME_STATE.IDLE
var velocity
var snap
var was_on_floor = true
var enemies_in_hurtbox = []
var target_position = Vector2(0,0)
var x_dir_to_player
var health = MAX_HEALTH


const TELEPORT_INDICATOR_GROUNDED_SCENE = preload("res://aiden/teleport_indicator_grounded.tscn")
const TELEPORT_INDICATOR_AIR_SCENE = preload("res://aiden/teleport_indicator_air.tscn")
var teleport_indicator


# === combat vars
var has_thrown_needles = false
var num_needles = 3
var spread_needles_probability = 0
var burst_counter = 0
var burst_amt = 0


# called on node beginning
func _ready():
	$CollisionShape2D.position = Vector2(-3, 13.25)
	$CollisionShape2D.scale = Vector2(5,8)
	Globals.enemy1 = self
	velocity = Vector2.ZERO
	
func warn():
	if is_instance_valid(teleport_indicator):
		return
		#teleport_indicator.queue_free()
	if target_position.y < -200:
		teleport_indicator = TELEPORT_INDICATOR_AIR_SCENE.instance()
	else:
		teleport_indicator = TELEPORT_INDICATOR_GROUNDED_SCENE.instance()
	teleport_indicator.target_position = target_position
	teleport_indicator.global_position = global_position
	#teleport_indicator.global_position = target_position - (target_position - global_position).normalized() * 300
	get_tree().get_root().add_child(teleport_indicator)
	
func die():
	pause_mode = Node.PAUSE_MODE_PROCESS
	$CollisionShape2D.queue_free()
	state = GAME_STATE.DEAD
	Engine.time_scale = 1.0
	Globals.camera.globadddddddddddddddddl_position = global_position
	get_tree().paused = true
	if is_instance_valid(teleport_indicator):
		teleport_indicator.queue_free()
	var particles = DEATH_PARTICLES_SCENE.instance()
	particles.global_position = global_position
	get_tree().get_root().add_child(particles)
	#queue_free()


func hurt(damage = 1):
	health -= damage
	$AnimatedSprite.modulate = Color(100,100,100)
	$ShakeTimer.start()
	Globals.ui.set_boss_health(100 * health / MAX_HEALTH)
	
	# phasing
	if health <= floor(MAX_HEALTH/3):
		base_color = Color.orangered
		spread_needles_probability = 1
		num_needles = 5
		burst_amt = 4
		$ActionTimer.wait_time = 3
	elif health <= floor(2*MAX_HEALTH/3):
		$ActionTimer.wait_time = 3
		base_color = Color.orange
		spread_needles_probability = 1
		burst_amt = 2
	elif health <= floor(5*MAX_HEALTH/6):
		burst_amt = 1
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

func get_random_pos():
	has_thrown_needles = false
	var exclude
	var min_dist = 99999
	for pos in [bl_corner, br_corner, tl_corner, tr_corner]:
		var dist = global_position.distance_to(pos)
		if dist < min_dist:
			exclude = pos
			min_dist = dist
	var chosen = randi() % 3
	for pos in [bl_corner, br_corner, tl_corner, tr_corner]:
		if pos == exclude:
			pass
		elif chosen == 0:
			return pos
		else:
			chosen -= 1
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
		$CollisionShape2D.position = Vector2(-3, 13.25)
		$CollisionShape2D.scale = Vector2(5,8)
		face_player()
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
		has_thrown_needles = false
	elif state == GAME_STATE.POOF:
		$AnimatedSprite.play("poof")
		warn()
	elif state == GAME_STATE.NEEDLE_THROW:
		$AnimatedSprite.play("needle_throw")
		if burst_counter > 0:
			warn()
		if $AnimatedSprite.frame >= 2 and has_thrown_needles == false:
			throw_needles(num_needles)
			if burst_counter > 0:
				teleport()
				burst_counter -= 1
			
		#process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_CHARGE:
		$AnimatedSprite.play("needle_charge")
		process_movement_gravity(delta)
	elif state == GAME_STATE.NEEDLE_THROW_AIR:
		$AnimatedSprite.play("needle_throw_air")
		if burst_counter > 0:
			warn()
		if $AnimatedSprite.frame >= 2 and has_thrown_needles == false:
			throw_needles(num_needles)
			if burst_counter > 0:
				teleport()
				target_position = get_random_pos()
				burst_counter -= 1
		
		if has_thrown_needles:
			process_movement_gravity(delta)
		
		if $FloorCast.is_colliding():
			state = GAME_STATE.LAND
		
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR:
		$AnimatedSprite.play("needle_charge_air")
		#process_movement_gravity(delta)
	elif state == GAME_STATE.LAND:
		$AnimatedSprite.play("idle")
		process_movement_gravity(delta)
	elif state == GAME_STATE.DEAD:
		modulate.a -= delta
		if modulate.a <= 0:
			Globals.camera.position = Vector2(0,0)
			get_tree().paused = false
			queue_free()
			get_tree().change_scene("res://levels/test_nick.tscn")
	
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
		choose_action()

# state transition functions
func begin_poof(position):
	$CollisionShape2D.position = Vector2(5,40)
	$CollisionShape2D.scale = Vector2(8,6)
	state = GAME_STATE.POOF
	target_position = position
	$PoofTimer.start()
	
func choose_action():
	var choice = randi() % 4
	# At the moment, these corners are fixed position
	# Maybe make it a random fixed distance from the player?

	# poof to bottom left corner, then throw needle at player
	if choice == 0:
		
		if global_position.x < 0:
			$CollisionShape2D.position = Vector2(10, 25)
			$CollisionShape2D.scale = Vector2(7,7)
			state = GAME_STATE.NEEDLE_CHARGE
			$WindupTimer.start()
		else:
			begin_poof(bl_corner)
	# poof to bottom right corner, then throw needle at player
	elif choice == 1:
		if global_position.x > 0:
			$CollisionShape2D.position = Vector2(10, 25)
			$CollisionShape2D.scale = Vector2(7,7)
			state = GAME_STATE.NEEDLE_CHARGE
			$WindupTimer.start()
		else:
			begin_poof(br_corner)
	# poof to top right corner, then throw needle at player
	elif choice == 2:
		begin_poof(tr_corner)
	# poof to top left corner, then throw needle at player
	else:
		begin_poof(tl_corner)
	
func teleport(target=target_position):
	if is_instance_valid(teleport_indicator):
		teleport_indicator.queue_free()
	
	var smoke = SMOKE_PARTICLES_SCENE.instance()
	smoke.global_position = global_position
	get_tree().get_root().add_child(smoke)

	# trail to show where she's going
	var poof_dir = (target - global_position).normalized()
	var total_distance = target.distance_to(global_position)

	var cur_distance = smoke_trail_distance
	while cur_distance <= total_distance:
		var little_smoke = SMOKE_PARTICLES_SCENE.instance()
		little_smoke.global_position = global_position + poof_dir * cur_distance
		little_smoke.scale = Vector2(1,1) * range_lerp(cur_distance, 0, total_distance, 0.1, 0.4)
		get_tree().get_root().add_child(little_smoke)
		cur_distance += smoke_trail_distance
	
	# move to the position
	global_position = target
	var smoke2 = SMOKE_PARTICLES_SCENE.instance()
	smoke2.global_position = global_position
	get_tree().get_root().add_child(smoke2)
	
	# face the player
	face_player()
	# change to needle state, this one is in the air
	if global_position.y < -100:
		$CollisionShape2D.position = Vector2(-5, 0)
		$CollisionShape2D.scale = Vector2(7,6)
		state = GAME_STATE.NEEDLE_CHARGE_AIR
		$WindupTimer.start()
		#velocity.y = -400
	# otherwise we're on the ground
	else:
		$CollisionShape2D.position = Vector2(10, 25)
		$CollisionShape2D.scale = Vector2(7,7)
		state = GAME_STATE.NEEDLE_CHARGE
		$WindupTimer.start()
	
	
	if burst_counter > 0:
		target_position = get_random_pos()

func throw_needles(n):
	if spread_needles_probability > rand_range(0,1):
		throw_spread_needles(n)
	else:
		throw_straight_needles(n)
	has_thrown_needles = true 

func throw_straight_needles(n):
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	if $FloorCast.is_colliding():
		dir_to_player = Vector2(1,0) * (-1 if $AnimatedSprite.flip_h else 1)
	for i in range(n):
		var needle = NEEDLE.instance()
		get_tree().current_scene.add_child(needle)
		
		needle.global_position = self.global_position + dir_to_player * rand_range(10,30) + dir_to_player.rotated(PI/2) * rand_range(-20, 20)
		needle.rotation = dir_to_player.angle()
		needle.dir = dir_to_player
	
func throw_spread_needles(n):
	
	var dir_to_player = (Globals.player.global_position - global_position).normalized()
	if $FloorCast.is_colliding():
		dir_to_player = Vector2(1,0) * (-1 if $AnimatedSprite.flip_h else 1)
	
	var spread = PI/6
	var initial_angle = sign(dir_to_player.x) * spread if not is_on_floor() else 0
	var final_angle = sign(dir_to_player.x) * -spread * 2
	for i in range(n):
		var needle = NEEDLE.instance()
		get_tree().current_scene.add_child(needle)
		
		needle.dir = dir_to_player.rotated(initial_angle + i * (final_angle - initial_angle) / n)
		needle.rotation = needle.dir.angle()
		needle.global_position = self.global_position + dir_to_player * 100
		
func _on_PoofTimer_timeout():
	if state == GAME_STATE.POOF:
		teleport()	
		
func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation == "idle" and state == GAME_STATE.LAND:
		state = GAME_STATE.IDLE

func _on_WindupTimer_timeout():
	if state == GAME_STATE.NEEDLE_CHARGE:
		$CollisionShape2D.position = Vector2(30,40)
		$CollisionShape2D.scale = Vector2(9,6)
		state = GAME_STATE.NEEDLE_THROW
		$WindupTimer.start()
	elif state == GAME_STATE.NEEDLE_CHARGE_AIR:
		$CollisionShape2D.position = Vector2(0,0)
		$CollisionShape2D.scale = Vector2(9,6)
		state = GAME_STATE.NEEDLE_THROW_AIR
	elif state == GAME_STATE.NEEDLE_THROW:
		state = GAME_STATE.IDLE
	
