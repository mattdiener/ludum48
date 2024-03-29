extends KinematicBody

signal player_health_change(new_hp)
signal player_death()
signal player_begin()

var is_player = true

const STARTING_HP = 100
var hp = STARTING_HP

var runMoveSpeed = 5.0
var moveSpeed = 3.0
var crouchMoveSpeed = 1.0
var velocity = Vector3.ZERO
var direction = Vector3(1, 0, 1)
var shootDirection = Vector3.ZERO
var isDirectionalShooting = false
var moving = false
var enteringCrouch = false
var crouching = false
var wasCrouching = false
var crouchFrames = 0
var crouchTime = 0.416
var running = false
var player_has_control = true
var main_menu_state = true

var strafing = false
var forward_strafe_direction = Vector3.ZERO
var side_strafe_direction = Vector3.ZERO

onready var room_manager = get_node("../RoomManager")
onready var tween = get_node("Tween")
onready var character_animation = get_node("Character/Animation")
onready var character = get_node("Character")
onready var weapon = find_node("Weapon")

onready var collision = get_node("CollisionShape")
onready var crouchCollision = get_node("CrouchCollisionShape")

enum PlayerMovementAnimations {
	CROUCH,
	CROUCH_IDLE,
	CROUCH_WALK,
	DEATH,
	IDLE,
	RUN
}

enum PlayerInteractionAnimations {
	INTERACT,
	SHOOT,
	IDLE
}

func is_dark():
	return false

func is_moving():
	return moving

func is_crouching():
	return crouching

func get_space_input():
	if Input.is_action_pressed("ui_accept"):
		emit_signal("player_begin")

func get_input():
	var tmp_direction = Vector3.ZERO
	shootDirection = Vector3.ZERO

	var forward = Input.get_action_strength("move_forward")
	var backward = Input.get_action_strength("move_backward")
	var left = Input.get_action_strength("move_left")
	var right = Input.get_action_strength("move_right")

	var shootForward = Input.get_action_strength("shoot_forward")
	var shootBackward = Input.get_action_strength("shoot_backward")
	var shootLeft = Input.get_action_strength("shoot_left")
	var shootRight = Input.get_action_strength("shoot_right")

	tmp_direction.x = backward + right - forward - left
	tmp_direction.z = backward + left - forward - right
	
	shootDirection.x = shootBackward + shootRight - shootForward - shootLeft
	shootDirection.z = shootLeft + shootBackward - shootRight - shootForward
	shootDirection = shootDirection.normalized()
	isDirectionalShooting = shootDirection.x != 0 or shootDirection.z != 0

	moving = false;
	if tmp_direction.x != 0 or tmp_direction.z != 0:
		if strafing:
			# When strafing, only allow front/back/left/right movement (WRT player)
			var forward_strafe_sign = forward_strafe_direction.dot(tmp_direction)
			var side_strafe_sign = side_strafe_direction.dot(tmp_direction)
			if forward_strafe_sign or side_strafe_sign:
				moving = true
				direction = (
					(forward_strafe_sign * forward_strafe_direction) +
					(side_strafe_sign * side_strafe_direction)
				).normalized()
		else:
			moving = true
			direction = tmp_direction.normalized()

	crouching = Input.is_action_pressed("crouch")
	running = Input.is_action_pressed("run")

	var pressing_shoot = Input.is_action_pressed("shoot")
	if pressing_shoot or isDirectionalShooting:
		weapon.begin_shoot()
	else:
		weapon.end_shoot()

	var pressing_strafe = Input.is_action_pressed("strafe")
	if not pressing_strafe and not isDirectionalShooting:
		strafing = false
	elif not strafing:
		strafing = true
		if not isDirectionalShooting:
			forward_strafe_direction = direction.normalized()
			side_strafe_direction = forward_strafe_direction.cross(Vector3.UP)
			
	
	if isDirectionalShooting:
		forward_strafe_direction = shootDirection.normalized()
		side_strafe_direction = forward_strafe_direction.cross(Vector3.UP)

func handle_crouch(delta):
	if not crouching:
		collision.disabled = false
		crouchCollision.disabled = true
		wasCrouching = false
		return

	collision.disabled = true
	crouchCollision.disabled = false

	if wasCrouching:
		crouchFrames += delta
	else:
		crouchFrames = 0
		wasCrouching = true

	if crouchFrames >= crouchTime:
		enteringCrouch = false
	else:
		enteringCrouch = true

func derive_animation_state():
	var move_animation = PlayerMovementAnimations.IDLE
	var interact_animation = PlayerInteractionAnimations.IDLE

	if is_alive():
		if crouching:
			if enteringCrouch:
				move_animation = PlayerMovementAnimations.CROUCH
			elif moving:
				move_animation = PlayerMovementAnimations.CROUCH_WALK
			else:
				move_animation = PlayerMovementAnimations.CROUCH_IDLE
		elif moving:
			move_animation = PlayerMovementAnimations.RUN

		if weapon.shooting:
			interact_animation = PlayerInteractionAnimations.SHOOT
	else:
		move_animation = PlayerMovementAnimations.DEATH

	character_animation.set("parameters/MovementTransition/current", move_animation)
	character_animation.set("parameters/InteractionTransition/current", interact_animation)

	var blend = 0.0001  # HACK. Cannot set to 0
	if interact_animation != PlayerInteractionAnimations.IDLE:
		blend = 1
	character_animation.set("parameters/FinalBlend/blend_amount", blend)

func get_look_direction():
	if isDirectionalShooting:
		return shootDirection.normalized()
	elif strafing:
		return forward_strafe_direction.normalized()
	return direction.normalized()

func is_alive():
	return hp > 0

func take_damage(amount: float):
	hp -= amount

	if hp <= 0:
		player_has_control = false
		emit_signal("player_health_change", 0)
		emit_signal("player_death")
	else:
		emit_signal("player_health_change", hp)


func move_to(position: Vector3):
	player_has_control = false
	strafing = false
	direction = (position - translation).normalized()

	tween.interpolate_property(
		self,
		"translation",
		translation,
		position - character.translation,
		1,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	tween.start()

func _on_reset():
	hp = STARTING_HP
	velocity = Vector3.ZERO
	direction = Vector3(1, 0, 1)
	weapon.end_shoot()
	player_has_control = true
	emit_signal("player_health_change", hp)
	
func gain_control():
	main_menu_state = false

func _physics_process(delta):
	moving = false
	crouching = false
	running = false

	if main_menu_state:
		get_space_input()
	elif player_has_control:
		get_input()
	else:
		moving = true

	var dir = ((transform.basis.z * direction.z) + (transform.basis.x * direction.x))

	if strafing:
		var strafe_look_dir = (
			(transform.basis.z * forward_strafe_direction.z) +
			(transform.basis.x * forward_strafe_direction.x)
		)
		character.look_at(translation - strafe_look_dir, Vector3.UP)
	else:
		character.look_at(translation - dir, Vector3.UP)

	handle_crouch(delta)

	var currentMoveSpeed = 0
	if moving:
		currentMoveSpeed = moveSpeed
		if crouching:
			currentMoveSpeed = crouchMoveSpeed
		elif running:
			currentMoveSpeed = runMoveSpeed

	if player_has_control:
		velocity.x = dir.x * currentMoveSpeed
		velocity.z = dir.z * currentMoveSpeed

		move_and_collide(velocity * delta)

		var nav_mesh = room_manager.get_active_navmesh()
		if nav_mesh:
			var room_offset = nav_mesh.get_parent().translation
			var room_coord = translation - room_offset
			var new_room_coord = nav_mesh.get_closest_point(room_coord)
			translation = new_room_coord + room_offset

	derive_animation_state()

func _on_room_entered(prev_room: Spatial, room: Spatial, entrance_position: Vector3, _room_count):
	if prev_room:
		move_to(entrance_position)

func _on_tween_completed(_object: Object, _key: NodePath):
	player_has_control = true
	moving = false

func _ready():
	character_animation.active = true
	room_manager.connect("room_entered", self, "_on_room_entered")
	tween.connect("tween_completed", self, "_on_tween_completed")
	weapon.bind_parent(self)
