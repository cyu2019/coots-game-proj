extends KinematicBody2D


# == numbers to tweak == 
const max_speed = 600 # How fast the player will move (pixels/sec).
const acceleration = 200

const gravity = 1600
const jump_speed = 300
var time_since_on_floor = 999
const coyote_time = 0.1

var time_since_jump_pressed = 0
const jump_buffer = 0.1

const DASH_SPEED = 1300
var dash_time = 0.25

const radius = 50
# ========================

# COMBO 1 = Falcon stomp
# COMBO 2 = Falcon kick air
# COMBO 3 = Falcon kick ground
enum GAME_STATE {IDLE, COMBO_1, COMBO_2, COMBO_3}
var state = GAME_STATE.IDLE

var velocity
var snap
var was_on_floor = true

var enemies_in_hurtbox = []
var is_invincible = false

#const AFTER_IMAGE = preload('res://AfterImage.tscn')

# called on node beginning
func _ready():
	Globals.enemy1 = self
	velocity = Vector2.ZERO

func hurt(damage=1):
	if is_invincible:
		return
	snap = Vector2.ZERO
	# Globals.ui.health = max(Globals.ui.health - 1, 0)
	# $HurtSound.play()
	# $InvincibilityTimer.start()
	is_invincible = true

func _on_InvincibilityTimer_timeout():
	is_invincible = false
func _on_InvincibilityFlashTimer_timeout():
	if not is_invincible:
		return
	
func _on_HurtBox_body_entered(body):
	if not body in enemies_in_hurtbox:
		enemies_in_hurtbox.append(body)
func _on_HurtBox_body_exited(body):
	var i = enemies_in_hurtbox.find(body)
	if i > -1:
		enemies_in_hurtbox.remove(i)

func move(dir, delta):
	velocity.x = dir.x * 100
	velocity.y = dir.y * 100
	var on_floor = is_on_floor()
	if(on_floor):
		velocity.y = 0

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
	var dir = (Globals.player.global_position - global_position).normalized()

	# if idle, make a choice on which of the three combos to use
	if state == GAME_STATE.IDLE:
		# Same y coordinate and on floor -> we'll try to kick towards them
		if(global_position.y < Globals.player.global_position.y + radius and 
			Globals.player.global_position.y - radius < global_position.y and was_on_floor):
			state = GAME_STATE.COMBO_3
			velocity = Vector2.ZERO
			pass
		# if within a certain radius of enemy, try to stomp them
		elif(global_position.x < Globals.player.global_position.x + radius and 
			 Globals.player.global_position.x - radius < global_position.x):
			state = GAME_STATE.COMBO_1
			velocity.x = 0
			velocity.y = -jump_speed * 2
			snap = Vector2.ZERO	
			pass
		# otherwise try a diagonal kick
		elif(global_position.y < Globals.player.global_position.y + radius and 
			 Globals.player.global_position.y - radius < global_position.y):
			state = GAME_STATE.COMBO_2
			velocity.x = 0
			velocity.y = -jump_speed
			snap = Vector2.ZERO	
			pass
		# otherwise move toward player
		else:
			velocity = Vector2.ZERO
			move(dir, delta)
	# if combo1, do a stomp
	elif state == GAME_STATE.COMBO_1:		
		# figure out how to extend hit box in a stomp formation
		# slime should also fall faster than gravity
		# current up speed is 2000 and then go down 2 * gravity
		# this part is the fall down faster, the jump part is in idle
		velocity.y += 2 * gravity * delta
		snap = Vector2.ZERO	
		if(was_on_floor):
			state = GAME_STATE.IDLE
		pass

	# if combo2, do a jump then diagonal kick
	elif state == GAME_STATE.COMBO_2:
		# slime should also fall faster than gravity
		# this part is the fall down faster, the jump part is in idle
		velocity.x += dir.x  * 100
		velocity.y += 0.5 * gravity * delta
		if(was_on_floor):
			state = GAME_STATE.IDLE
		pass
	# if combo3, do a kick across the ground
	elif state == GAME_STATE.COMBO_3:
		# just move in the x direction fast
		velocity.x += dir.x * 200
		if(was_on_floor):
			state = GAME_STATE.IDLE
		pass
		
	move_and_slide_with_snap(velocity, snap, Vector2.UP)

func attack():
	if state == GAME_STATE.COMBO_1:
		pass
	elif state == GAME_STATE.COMBO_2:
		pass
	elif state == GAME_STATE.COMBO_3:
		pass
	else:
		pass

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
