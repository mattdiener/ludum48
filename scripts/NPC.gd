extends KinematicBody

enum Type { Patrol, Boss, Idle }
enum Style { Alien, Animal, Military, Robot, Zombie }
enum NPCState { None, Patrol, Stand, Chase, Cover, Punch, Kick, Strafe }

const ALIEN_MATERIALS = ["res://res/material/alienA.tres", "res://res/material/alienB.tres"]
const ANIMAL_MATERIALS = ["res://res/material/animalA.tres", "res://res/material/animalB.tres", "res://res/material/animalC.tres", "res://res/material/animalD.tres", "res://res/material/animalG.tres", "res://res/material/animalJ.tres"]
const MILITARY_MATERIALS = ["res://res/material/cyborg.tres", "res://res/material/militaryMaleA.tres", "res://res/material/militaryMaleB.tres"]
const ROBOT_MATERIALS = ["res://res/material/robot.tres", "res://res/material/robot2.tres", "res://res/material/robot3.tres"]
const ZOMBIE_MATERIALS = ["res://res/material/zombieA.tres", "res://res/material/zombieB.tres", "res://res/material/zombieC.tres"]

const NPC_MATERIALS = [
	ALIEN_MATERIALS,
	ANIMAL_MATERIALS,
	MILITARY_MATERIALS,
	ROBOT_MATERIALS,
	ZOMBIE_MATERIALS
]

enum PlayerAnimations {
	ATTACK,
	CROUCH,
	DEATH,
	IDLE,
	KICK,
	PUNCH,
	RUN,
	SHOOT,
	WALK,
	PUNCH_WALK,
	KICK_WALK,
	SHOOT_WALK
}

export(Type) var type = 0
export(NodePath) var roomPath = null
export(NodePath) var playerPath = null
export(Style) var style = 0

#CONSTS
const minStand = 5.0
const maxStand = 10.0
const rotationThreshold = 0.05
const distanceThreshold = 1.0
const viewDistance = 8.0
const hearDistance = 3.0
const fov = 1.4 #radians
const cast_dist_tolerance = 0.3

#objects
var navmesh = null
var room = null
var player = null
onready var mesh = get_node("characterLargeMale/Root/Skeleton/characterLargeMale")
onready var character_animation = get_node("characterLargeMale/AnimationTree")
onready var eye_position = get_node("EyePosition")
onready var indicator = get_node("Indicator")
onready var character = self

#Movement
var currentState : int = NPCState.Stand
var runSpeed = 2.8
var walkSpeed = 1.0
var velocity = Vector3.ZERO
var direction = Vector3.ZERO
var moving = false
var enteringCrouch = false
var crouching = false
var wasCrouching = false
var crouchFrames = 0
var crouchTime = 0.416
var running = false

# AI State machine data
var lastState = NPCState.None
var stateTimer = 0
var stateMaxTime = 0
var destination = null

func init(type, room, player, style):
	self.type = type
	self.room = room
	self.player = player
	self.style = style

func _ready():
	var material_res = NPC_MATERIALS[style][randi() % NPC_MATERIALS[style].size()]
	var material = ResourceLoader.load(material_res)
	mesh["material/0"] = material
	character_animation.set("parameters/Transition/current", PlayerAnimations.IDLE)

	if room:
		 navmesh = room.get_navmesh()

	if roomPath != null:
		room = get_node(roomPath)

	if playerPath != null:
		player = get_node(playerPath) 
	
	direction = Vector3(randf(), 0, randf()).normalized()
	
	character.look_at(global_transform.origin + direction, Vector3(0,1,0))
	indicator.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Do different control based on state
	if currentState == NPCState.Patrol:
		handle_patrol(delta)
	elif currentState == NPCState.Stand:
		handle_stand(delta)
	elif currentState == NPCState.Chase:
		pass
	elif currentState == NPCState.Cover:
		pass
	elif currentState == NPCState.Punch:
		pass
	elif currentState == NPCState.Kick:
		pass
	elif currentState == NPCState.Strafe:
		pass

	var currentMoveSpeed = 0
	if moving:
		character.look_at(global_transform.origin + direction, Vector3(0,1,0))
		currentMoveSpeed = walkSpeed
		if running:
			currentMoveSpeed = runSpeed

	velocity.x = direction.x * currentMoveSpeed
	velocity.z = direction.z * currentMoveSpeed

	move_and_collide(velocity * delta)

	if navmesh:
		translation = navmesh.get_closest_point(translation)
	
	derive_animation_state()

func can_see_player():
	# first find out if player is in fov
	var vec_to_player = player.global_transform.origin - global_transform.origin
	if direction.angle_to(vec_to_player) > fov/2.0:
		return false
	
	# if the player is close enough, we don't want to bother raycasting (it won't work)
	if vec_to_player.length() < hearDistance:
		return true
	
	if vec_to_player.length() > viewDistance:
		return false
	
	# now cast a ray to the player and see if we hit anything besides the player
	var space_state = get_world().direct_space_state
	var ray_cast = space_state.intersect_ray(eye_position.global_transform.origin, player.global_transform.origin)
	
	if ray_cast and "position" in ray_cast:
		var cast_player_dist = ray_cast.position.distance_to(player.global_transform.origin)
		if cast_player_dist > cast_dist_tolerance:
			return false
		
	# if player is in sight, check to see whether they are "hidden"
	if player.is_moving() or not player.is_dark():
		return true
		
	return false

func can_hear_player():
	if player.is_moving() and player.global_transform.origin.distance_to(global_transform.origin) <= hearDistance:
		return true
	return false

func near_destination():
	var dist = translation.distance_to(destination.translation)

	if dist <= distanceThreshold:
		return true

	return false

func handle_patrol(delta):
	moving = false
	running = false
	crouching = false

	if lastState != currentState:
		enter_patrol()
	lastState = currentState

	if can_see_player():
		indicator.show()
	else:
		indicator.hide()
	
	if destination == null:
		exit_patrol()
		return

	if near_destination():
		exit_patrol()
		return

	var tra = translation
	var pra = player.translation
	var rra = room.translation
	
	direction = navmesh.get_simple_path(translation, destination.translation)[1] - translation
	direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, randf()*rotationThreshold*2 - rotationThreshold)
	moving = true

func enter_patrol():
	if room != null:
		var tries = 0
		while destination == null or near_destination():
			if tries >= 3:
				destination = null
				break

			var waypoints = room.get_waypoints()
			destination = waypoints[randi() % waypoints.size()]
			tries += 1

func exit_patrol():
	var exit_states = [NPCState.Stand, NPCState.Patrol]
	currentState = exit_states[randi() % exit_states.size()]

func handle_stand(delta):
	if lastState != currentState:
		enter_stand()
	lastState = currentState
	
	if can_see_player():
		indicator.show()
	else:
		indicator.hide()
	
	if stateTimer >= stateMaxTime:
		exit_stand()

	stateTimer += delta

func enter_stand():
	stateTimer = 0
	stateMaxTime = randf() * (maxStand - minStand) + minStand

func exit_stand():
	var exit_states = [NPCState.Stand, NPCState.Patrol]
	currentState = exit_states[randi() % exit_states.size()]

func derive_animation_state():
	if crouching and enteringCrouch:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH)
	elif crouching and not moving:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_IDLE)
	elif crouching:
		character_animation.set("parameters/Transition/current", PlayerAnimations.CROUCH_WALK)
	elif moving and running:
		character_animation.set("parameters/Transition/current", PlayerAnimations.RUN)
	elif moving:
		character_animation.set("parameters/Transition/current", PlayerAnimations.WALK)
	else:
		character_animation.set("parameters/Transition/current", PlayerAnimations.IDLE)

