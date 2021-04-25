extends KinematicBody

var runMoveSpeed = 5.0
var moveSpeed = 3.0
var crouchMoveSpeed = 1.0
var velocity = Vector3.ZERO
var direction = Vector3.ZERO
var moving = false
var enteringCrouch = false
var crouching = false
var wasCrouching = false
var crouchFrames = 0
var crouchTime = 0.416
var running = false
var player_has_control = true

onready var room_manager = get_node("../RoomManager")
onready var tween = get_node("Tween")
onready var character_animation = get_node("Character/Animation")
onready var character = get_node("Character")

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
		moving = true
		direction = tmp_direction.normalized()

	crouching = Input.is_action_pressed("crouch")
	running = Input.is_action_pressed("run")

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
	if crouching and enteringCrouch:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH)
	elif crouching and not moving:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_IDLE)
	elif crouching:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_WALK)
	elif moving:
		character_animation.set("parameters/Transition/current", PlayerAnimations.RUN)
	else:
		character_animation.set("parameters/Transition/current", PlayerAnimations.IDLE)

func move_to(position: Vector3):
	player_has_control = false
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
	character.look_at(translation - dir, Vector3(0,1,0))

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
