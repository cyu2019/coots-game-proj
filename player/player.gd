extends KinematicBody2D


const IS_PLAYER = true


const SLASH_SCENE = preload("res://player/slash/slash.tscn")

# == numbers to tweak == 
const max_speed = 600 # How fast the player will move (pixels/sec).
const acceleration = 200

const gravity = 1600
const jump_speed = 1100
var time_since_on_floor = 999
const coyote_time = 0.1

var time_since_jump_pressed = 0
const jump_buffer = 0.1

const DASH_SPEED = 1300
var dash_time = 0.25
# ========================

enum GAME_STATE {MOVEMENT, DASH, ATTACK, ATTACK_SLASHED}
var state = GAME_STATE.MOVEMENT
var can_dash = true


var velocity
var snap
var was_on_floor = true


var enemies_in_hurtbox = []
var is_invincible = false

#const AFTER_IMAGE = preload('res://AfterImage.tscn')


# called on node beginning
func _ready():
	Globals.player = self
	velocity = Vector2.ZERO


# the way we currently get variable jump heights is to cut the jump speed when the player releases the jump button.
func jump_cut():
	if velocity.y < -100:
		velocity.y /= 2

func hurt(damage=1):
	if is_invincible or state == GAME_STATE.DASH or Globals.ui.won:
		return
	
	snap = Vector2.ZERO
	$Camera2D.shake(400, 0.3)
	Globals.ui.health = max(Globals.ui.health - 1, 0)
	$HurtSound.play()
	$InvincibilityTimer.start()
	is_invincible = true
	$AnimatedSprite.modulate.a = 0.5

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
	if not body in enemies_in_hurtbox:
		enemies_in_hurtbox.append(body)
func _on_HurtBox_body_exited(body):
	var i = enemies_in_hurtbox.find(body)
	if i > -1:
		enemies_in_hurtbox.remove(i)

func squashy_stretch(delta):
	$AnimatedSprite.scale.y = lerp($AnimatedSprite.scale.y, 0.3 - abs(velocity.x)/max_speed/50, delta*5)
	$AnimatedSprite.scale.x = lerp($AnimatedSprite.scale.x, 0.3 - abs(velocity.y)/max_speed/50, delta*5)
	if is_on_floor() and not was_on_floor:
		$AnimatedSprite.scale.y = 0.28

# called every frame
func _process(delta):	
	# handles falling to their death
	if global_position.y > 5000:
		hurt()
	
	#squashy_stretch(delta)
	was_on_floor = is_on_floor()
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
		
	move_and_slide_with_snap(velocity, snap, Vector2.UP)

func dash():
	state = GAME_STATE.DASH
	can_dash = false
	#$DashSound.play()
	$DashCooldownTimer.start()
	$DashTimer.start(dash_time)
	var dir = 1
	if ($AnimatedSprite.flip_h):
		dir = -1
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
	
	if Input.is_action_pressed("move_right"):
		velocity.x += acceleration
	elif Input.is_action_pressed("move_left"):
		velocity.x -= acceleration
	else:
		velocity.x += -sign(velocity.x) * acceleration
	
	velocity.x = sign(velocity.x) * min(max_speed, abs(velocity.x))
	
	velocity.y += gravity * delta

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
		if velocity.x < 0:
			$AnimatedSprite.flip_h = true
		elif velocity.x > 0:
			$AnimatedSprite.flip_h = false

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


"""
# used to be code that sent after images behind you when you dashed
func _on_AfterImageTimer_timeout():
	if is_dashing:
		var after_image = AFTER_IMAGE.instance()
		after_image.flip($AnimatedSprite.flip_h)
		after_image.global_position = global_position
		get_tree().get_root().add_child(after_image)	
"""

