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

onready var room_manager = get_node("../RoomManager")
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
	
	if Input.is_action_pressed("move_forward"):
		tmp_direction.x -= 1
		tmp_direction.z -= 1
	if Input.is_action_pressed("move_backward"):
		tmp_direction.x += 1
		tmp_direction.z += 1
	if Input.is_action_pressed("move_left"):
		tmp_direction.x -= 1
		tmp_direction.z += 1
	if Input.is_action_pressed("move_right"):
		tmp_direction.x += 1
		tmp_direction.z -= 1
	
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

func _physics_process(delta):
	get_input()
	
	var dir = ((transform.basis.z * direction.z) + (transform.basis.x * direction.x))
	
	handle_crouch(delta)
	
	var currentMoveSpeed = 0
	if moving:
		character.look_at(translation - dir, Vector3(0,1,0)) 
		
		currentMoveSpeed = moveSpeed
		if crouching:
			currentMoveSpeed = crouchMoveSpeed
		elif running:
			currentMoveSpeed = runMoveSpeed
	
	velocity.x = dir.x * currentMoveSpeed
	velocity.z = dir.z * currentMoveSpeed
	
	move_and_collide(velocity * delta)

	var nav_mesh = room_manager.get_active_navmesh()
	if nav_mesh:
		translation = nav_mesh.get_closest_point(translation)
		
	derive_animation_state()

# Called when the node enters the scene tree for the first time.
func _ready():
	character_animation.active = true
	character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_IDLE)
