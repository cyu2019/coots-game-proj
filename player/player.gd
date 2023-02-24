extends KinematicBody2D


const IS_PLAYER = true


const SLASH_SCENE = preload("res://player/slash/slash.tscn")
const POOF_SCENE = preload("res://player/poof/poof.tscn")
const AFTER_IMAGE = preload("res://player/after_image.tscn")
const CROSS_IMPACT = preload("res://player/slash-impacts/cross_impact.tscn")

signal health_changed(amt)

# == numbers to tweak == 
const max_speed = 800 # How fast the player will move (pixels/sec).
const acceleration = 400

const gravity = 3000
const jump_speed = 1400
var time_since_on_floor = 999
const coyote_time = 0.1

var time_since_jump_pressed = 0
const jump_buffer = 0.1

const DASH_SPEED = 1400
var dash_time = 0.25
# ========================


var cur_dir_intent = 0

enum GAME_STATE {MOVEMENT, DASH, ATTACK, ATTACK_SLASHED}
var state = GAME_STATE.MOVEMENT
var can_dash = true


var velocity
var snap
var should_flip = false
var was_on_floor = true

const initial_sprite_scale = 0.3

var enemies_in_hurtbox = []
var is_invincible = false
var health = 30

# called on node beginning
func _ready():
	Globals.player = self
	velocity = Vector2.ZERO
	


# the way we currently get variable jump heights is to cut the jump speed when the player releases the jump button.
func jump_cut():
	if velocity.y < -100:
		velocity.y /= 2

func hurt(damage=1):
	if is_invincible or state == GAME_STATE.DASH:
		return
	Globals.frameFreeze(0.05, 0.5)
	snap = Vector2.ZERO
	$Camera2D.shake(400, 0.3)

	$HurtSound.play()
	health = health - damage

	$InvincibilityTimer.start()
	
	var impact = CROSS_IMPACT.instance()
	impact.global_position = global_position
	get_tree().get_root().add_child(impact)
	impact.rotation = rand_range(-PI,PI)
	
	is_invincible = true
	$AnimatedSprite.modulate.a = 0.5
	emit_signal("health_changed", - damage)

func _on_InvincibilityTimer_timeout():
	$AnimatedSprite.modulate.a = 1
	is_invincible = false
func _on_InvincibilityFlashTimer_timeout():
	if not is_invincible:
		return
	
	if $AnimatedSprite.modulate.a == 1:
		$AnimatedSprite.modulate.a = 0.5
	else:
		$AnimatedSprite.modulate.a = 1
	
func _on_HurtBox_body_entered(body):
	if not body in enemies_in_hurtbox and "IS_ENEMY" in body:
		enemies_in_hurtbox.append(body)
		
func _on_HurtBox_body_exited(body):
	var i = enemies_in_hurtbox.find(body)
	if i > -1:
		enemies_in_hurtbox.remove(i)

func squashy_stretch(delta):
	#https://www.youtube.com/watch?v=iJx6uKqufJo
	
	if not is_on_floor() or state == GAME_STATE.DASH:
		$AnimatedSprite.scale.y = range_lerp(abs(velocity.y), 0, abs(jump_speed), 0.9, 1.3) * initial_sprite_scale
		$AnimatedSprite.scale.x = range_lerp(abs(velocity.y), 0, abs(jump_speed), 1.1, 0.9) * initial_sprite_scale
	
	
	if is_on_floor() and not was_on_floor:
		$AnimatedSprite.scale.y = range_lerp(abs(velocity.y), 0, abs(1700), 0.8, 0.6) * initial_sprite_scale
		$AnimatedSprite.scale.x = range_lerp(abs(velocity.y), 0, abs(1700), 1.1, 1.4) * initial_sprite_scale
	
	$AnimatedSprite.scale.x = lerp($AnimatedSprite.scale.x, initial_sprite_scale, 1 - pow(0.01, delta))
	$AnimatedSprite.scale.y = lerp($AnimatedSprite.scale.y, initial_sprite_scale, 1 - pow(0.01, delta))

# called every frame
func _process(delta):	
	# handles falling to their death
	if global_position.y > 5000:
		hurt()
	
	var bus_index = AudioServer.get_bus_index("EffectBus")
	var effect = AudioServer.get_bus_effect(bus_index, 0)
	if is_invincible:
		effect.cutoff_hz = 500
	else:
		effect.cutoff_hz = lerp(effect.cutoff_hz, 9000, delta)
	
	
	squashy_stretch(delta)
	# if there is ground within this vector it will stick the player to the ground so they can walk down slopes
	# see move_and_slide_with_snap
	snap = Vector2.DOWN * 16

	if len(enemies_in_hurtbox) > 0:
		hurt()
	
	if state == GAME_STATE.MOVEMENT:
		process_movement(delta)
		
		if Input.is_action_just_pressed("dash") and can_dash:
			dash()
		
		if Input.is_action_just_pressed("attack"):
			attack()
	
			#$Camera2D.shake(200, 0.3)
			pass

	elif state == GAME_STATE.ATTACK:
		process_movement(delta)
		
		#if $AnimatedSprite.animation.begins_with("attack") and $AnimatedSprite.frame >= 2:
		if $AnimatedSprite.animation.begins_with("attack") and $AnimatedSprite.frame >= 2:
			spawn_slash()

	elif state == GAME_STATE.ATTACK_SLASHED:
		process_movement(delta)

	elif state == GAME_STATE.DASH:
		
		"""
		# code that used to cancel dashing if you pressed it twice
		if Input.is_action_just_pressed("dash"):
			is_dashing = false
		"""
		pass
	
	was_on_floor = is_on_floor()
	move_and_slide_with_snap(velocity, snap, Vector2.UP)

func dash():
	state = GAME_STATE.DASH
	can_dash = false
	#$DashSound.play()
	$DashCooldownTimer.start()
	
	_on_AfterImageTimer_timeout()
	$AfterImageTimer.start()
	
	$DashTimer.start(dash_time)
	var dir = 1
	if ($AnimatedSprite.flip_h):
		dir = -1
		
	var poof = POOF_SCENE.instance()
	poof.global_position = global_position
	poof.flip_h = not $AnimatedSprite.flip_h
	get_tree().get_root().add_child(poof)
		
	velocity = DASH_SPEED * Vector2(dir, 0)
	$AnimatedSprite.play("dash")

func attack():
	state = GAME_STATE.ATTACK
	if not is_on_floor() and Input.is_action_pressed("down"):
		$AnimatedSprite.play("attack_down")
	elif Input.is_action_pressed("up"):
		$AnimatedSprite.play("attack_up")
	else:
		$AnimatedSprite.play("attack")
func spawn_slash():
	
	var offset_dir = Vector2(-1 if $AnimatedSprite.flip_h else 1, 0)
	if $AnimatedSprite.animation == "attack_up":
		offset_dir = Vector2(0,-1)
	elif $AnimatedSprite.animation == "attack_down":
		offset_dir = Vector2(0, 1)
		
	var slash = SLASH_SCENE.instance()
	slash.init(offset_dir)
	#slash.init(global_position, offset_dir)
	#get_tree().get_root().add_child(slash)
	add_child(slash)
	state = GAME_STATE.ATTACK_SLASHED
func process_movement(delta):
	
	
	var on_floor = is_on_floor()
	
	
	if Input.is_action_just_pressed("move_right"):
		cur_dir_intent = 1
	elif Input.is_action_just_pressed("move_left"): 
		cur_dir_intent = -1
			
			
	if Input.is_action_pressed("move_right") and cur_dir_intent != -1:
		if velocity.x == 0 and is_on_floor() or is_on_floor() and not was_on_floor:
			var poof = POOF_SCENE.instance()
			poof.global_position = global_position
			poof.flip_h = true
			get_tree().get_root().add_child(poof)
		velocity.x += acceleration
		should_flip = false
	elif Input.is_action_pressed("move_left") and cur_dir_intent != 1:
		
		if velocity.x == 0 and is_on_floor() or is_on_floor() and not was_on_floor:
			var poof = POOF_SCENE.instance()
			poof.global_position = global_position
			get_tree().get_root().add_child(poof)
		velocity.x -= acceleration
		should_flip = true
	else:
		cur_dir_intent = 0
		velocity.x += -sign(velocity.x) * acceleration
	
	
	
	velocity.x = sign(velocity.x) * min(max_speed, abs(velocity.x))
	
	velocity.y += gravity * delta
	#velocity.y += gravity

	time_since_on_floor += delta
	time_since_jump_pressed += delta

	if on_floor:
		time_since_on_floor = 0
		velocity.y = 0
		
	if Input.is_action_just_pressed("jump"):
		time_since_jump_pressed = 0
	
	if time_since_jump_pressed < jump_buffer and Input.is_action_pressed("jump"):
		if time_since_on_floor < coyote_time:
			#$JumpSound.play()
			velocity.y = -jump_speed
			snap = Vector2.ZERO	
			time_since_jump_pressed = 999
		else:
			# double jump
			pass
	
	if Input.is_action_just_released("jump"):
		jump_cut()

	if state == GAME_STATE.MOVEMENT:
		$AnimatedSprite.flip_h = should_flip

		if velocity.y > 0:
			$AnimatedSprite.play("fall")
		elif velocity.y < 0:
			$AnimatedSprite.play("jump")
		elif abs(velocity.x) > 0:
			if $AnimatedSprite.animation == "fall": # was falling, play landing sound
				#$JumpSound.play() 
				pass
			$AnimatedSprite.play("run")
		else:
			if $AnimatedSprite.animation == "fall": # was falling, play landing sound
				#$JumpSound.play()
				pass 
			
			$AnimatedSprite.play("idle")
	
	"""
	#old footstep code
	if $AnimatedSprite.animation == "run" and not $FootstepSound.playing:
		$FootstepSound.play()
	elif $AnimatedSprite.animation != "run":
		$FootstepSound.stop()	
	"""

func _on_DashTimer_timeout():
	if state == GAME_STATE.DASH:
		state = GAME_STATE.MOVEMENT

func _on_DashCooldownTimer_timeout():
	can_dash = true

func _on_AnimatedSprite_animation_finished():
	if $AnimatedSprite.animation.begins_with("attack") and (state == GAME_STATE.ATTACK or state == GAME_STATE.ATTACK_SLASHED):
		state = GAME_STATE.MOVEMENT
	
	pass # Replace with function body.



# used to be code that sent after images behind you when you dashed
func _on_AfterImageTimer_timeout():
	if state == GAME_STATE.DASH:
		var after_image = AFTER_IMAGE.instance()
		after_image.flip($AnimatedSprite.flip_h)
		after_image.global_position = global_position
		get_tree().get_root().add_child(after_image)	
