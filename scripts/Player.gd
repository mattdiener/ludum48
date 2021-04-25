extends KinematicBody

var runMoveSpeed = 5.0
var moveSpeed = 3.0
var crouchMoveSpeed = 1.0
var velocity = Vector3.ZERO
var direction = Vector3(1, 0, 1)
var moving = false
var enteringCrouch = false
var crouching = false
var wasCrouching = false
var crouchFrames = 0
var crouchTime = 0.416
var running = false
var player_has_control = true

var strafing = false
var forward_strafe_direction = Vector3.ZERO
var side_strafe_direction = Vector3.ZERO

onready var room_manager = get_node("../RoomManager")
onready var tween = get_node("Tween")
onready var character_animation = get_node("Character/Animation")
onready var character = get_node("Character")
onready var weapon = find_node("Weapon")

enum PlayerAnimations {
	CROUCH,
	CROUCH_IDLE,
	CROUCH_WALK,
	DEATH,
	IDLE,
	INTERRACT,
	RUN,
	SHOOT,
	RUN_SHOOT,
	CROUCH_SHOOT
	CROUCH_WALK_SHOOT
}

func is_dark():
	return false
	
func is_moving():
	return moving

func get_input():
	var tmp_direction = Vector3.ZERO

	var forward = Input.get_action_strength("move_forward")
	var backward = Input.get_action_strength("move_backward")
	var left = Input.get_action_strength("move_left")
	var right = Input.get_action_strength("move_right")

	tmp_direction.x = backward + right - forward - left
	tmp_direction.z = backward + left - forward - right

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
	if pressing_shoot:
		weapon.begin_shoot()
	else:
		weapon.end_shoot()

	var pressing_strafe = Input.is_action_pressed("strafe")
	if not pressing_strafe:
		strafing = false
	elif not strafing:
		forward_strafe_direction = direction.normalized()
		side_strafe_direction = forward_strafe_direction.cross(Vector3.UP)
		strafing = true

func handle_crouch(delta):
	if not crouching:
		wasCrouching = false
		return

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
	var animation = PlayerAnimations.IDLE

	if crouching:
		if enteringCrouch:
			animation = PlayerAnimations.CROUCH
		elif moving:
			if weapon.shooting:
				animation = PlayerAnimations.CROUCH_WALK
			else:
				animation = PlayerAnimations.CROUCH_WALK_SHOOT
		else:
			if weapon.shooting:
				animation = PlayerAnimations.CROUCH_SHOOT
			else:
				animation = PlayerAnimations.CROUCH_IDLE
	elif moving:
		if weapon.shooting:
			animation = PlayerAnimations.RUN_SHOOT
		else:
			animation = PlayerAnimations.RUN
	elif weapon.shooting:
		animation = PlayerAnimations.SHOOT

	character_animation.set("parameters/Transition/current", animation)

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

func _physics_process(delta):
	moving = false
	crouching = false
	running = false

	if player_has_control:
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

func _on_room_entered(prev_room: Spatial, room: Spatial, entrance_position: Vector3):
	if prev_room:
		move_to(entrance_position)

func _on_tween_completed(_object: Object, _key: NodePath):
	player_has_control = true
	moving = false

func _ready():
	character_animation.active = true
	character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_IDLE)
	room_manager.connect("room_entered", self, "_on_room_entered")
	tween.connect("tween_completed", self, "_on_tween_completed")
