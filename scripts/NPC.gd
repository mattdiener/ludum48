extends KinematicBody

signal health_change(new_hp)
signal npc_alert(npc)
signal npc_unalert(npc)

enum Type { Patrol, Boss, Idle }
enum Style { Alien, Animal, Military, Robot, Zombie }
enum NPCState { None, Patrol, Stand, Chase, SeekCover, Cover, StandCover, Punch, Kick, Strafe, Alert }

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

enum PlayerMovementAnimations {
	ATTACK,
	CROUCH,
	DEATH,
	IDLE,
	KICK,
	PUNCH,
	RUN,
	WALK
}

enum PlayerInteractionAnimations {
	SHOOT,
	IDLE
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
const coverDistanceThreshold = 0.4
const viewDistance = 8.0
const hearDistance = 3.0
const fov = 1.4 #radians
const cast_dist_tolerance = 0.3
const detectedMaxTime = 1.5
const alertTime = 1.25
const minChase = 4.0
const maxChase = 10.0
const minCover = 2.0
const maxCover = 8.0
const punchTime = 1.2
const kickTime = 1.2
const dealDamageDelay = 0.6
const punchDamage = 10
const kickDamage = 15
const meleeDistance = 0.5

#objects
var navmesh = null
var room = null
var player = null
onready var mesh = get_node("characterLargeMale/Root/Skeleton/characterLargeMale")
onready var character_animation = get_node("characterLargeMale/AnimationTree")
onready var health_bar = get_node("HealthMesh/HealthViewport/UI")
onready var eye_position = get_node("EyePosition")
onready var character = self
onready var weapon = find_node("Weapon")
onready var collision_shape = find_node("CollisionShape")

#Movement
var currentState : int = NPCState.Stand
var runSpeed = 2.8
var walkSpeed = 1.0
var velocity = Vector3.ZERO
var direction = Vector3.ZERO
var moving = false
var enteringCrouch = false
var crouching = false
var punching = false
var kicking = false
var wasCrouching = false
var crouchFrames = 0
var crouchTime = 0.416
var running = false
var alerted = false
var strafing = false
var sawPlayer = false

# AI State machine data
var lastState = NPCState.None
var stateTimer = 0
var stateMaxTime = 0
var detectedTime = 0
var destination = null

var hp = 100
var prev_hp = 100
var dealtDamage = false

func init(type, room, player, style):
	self.type = type
	self.room = room
	self.player = player
	self.style = style

func _ready():
	var material_res = NPC_MATERIALS[style][randi() % NPC_MATERIALS[style].size()]
	var material = ResourceLoader.load(material_res)
	mesh["material/0"] = material

	if room:
		 navmesh = room.get_navmesh()

	if roomPath != null:
		room = get_node(roomPath)

	if playerPath != null:
		player = get_node(playerPath)

	direction = Vector3(randf(), 0, randf()).normalized()

	character.look_at(global_transform.origin + direction, Vector3(0,1,0))

	weapon.bind_parent(self)
	health_bar.init(self, 100)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if is_alive() and currentState != NPCState.None:
		# Do different control based on state
		if currentState == NPCState.Patrol:
			handle_patrol(delta)
		elif currentState == NPCState.Stand:
			handle_stand(delta)
		elif currentState == NPCState.Chase:
			handle_chase(delta)
		elif currentState == NPCState.SeekCover:
			handle_seek_cover(delta)
		elif currentState == NPCState.Cover:
			handle_cover(delta)
		elif currentState == NPCState.StandCover:
			handle_stand_cover(delta)
		elif currentState == NPCState.Punch:
			handle_punch(delta)
		elif currentState == NPCState.Kick:
			handle_kick(delta)
		elif currentState == NPCState.Strafe:
			handle_strafe(delta)
		elif currentState == NPCState.Alert:
			handle_alert(delta)

		if strafing and not punching and not kicking:
			var can_see = can_see_player()
			if (can_see and not sawPlayer):
				weapon.begin_shoot()
				sawPlayer = true
			elif (sawPlayer and not can_see):
				weapon.end_shoot()
				sawPlayer = false

		var currentMoveSpeed = 0

		if strafing:
				character.look_at(player.global_transform.origin, Vector3(0,1,0))
		if moving:
			if not strafing:
				# TODO: fix "look_at_from_position: Node origin and target are in the same position, look_at() failed."
				character.look_at(global_transform.origin + direction, Vector3(0,1,0))
			currentMoveSpeed = walkSpeed
			if running:
				currentMoveSpeed = runSpeed

		velocity.x = direction.x * currentMoveSpeed
		velocity.z = direction.z * currentMoveSpeed

		move_and_collide(velocity * delta)

		if navmesh:
			translation = navmesh.get_closest_point(translation)

		prev_hp = hp

	derive_animation_state()

func get_look_direction():
	if strafing:
		return (player.global_transform.origin - global_transform.origin).normalized()
	return direction.normalized()

func is_alive():
	return hp > 0

func take_damage(amount: float):
	hp -= amount
	hp = max(hp, 0)
	
	emit_signal("health_change", hp)

	if hp <= 0:
		collision_shape.disabled = true
		emit_signal("npc_unalert", self)

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
	if player.is_moving() and player.global_transform.origin.distance_to(global_transform.origin) <= hearDistance and not player.is_crouching():
		return true
	return false

func can_melee_player():
	return player.global_transform.origin.distance_to(global_transform.origin) <= meleeDistance

func near_destination():
	var dist = translation.distance_to(destination.translation)

	if dist <= distanceThreshold:
		return true

	return false

func near_cover_destination():
	var dist = translation.distance_to(destination.translation)

	if dist <= coverDistanceThreshold:
		return true

	return false

func react_to_player(delta):
	var detected = false

	# If touching or hit, alert instantly
	if can_melee_player() or hp != prev_hp:
		currentState = NPCState.Alert
		return true

	if can_see_player():
		detected = true

	if can_hear_player():
		detected = true

	if detected:
		detectedTime += delta
	else:
		detectedTime = 0

	if detectedTime >= detectedMaxTime:
		currentState = NPCState.Alert
		return true

	return false

func handle_patrol(delta):
	moving = false
	running = false
	crouching = false

	if lastState != currentState:
		enter_patrol()
	lastState = currentState

	if react_to_player(delta):
		return

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
	stateTimer = 0

func handle_seek_cover(delta):
	moving = false
	running = false
	crouching = false

	if lastState != currentState:
		enter_seek_cover()
	lastState = currentState

	if destination == null:
		exit_alert()
		return

	if near_cover_destination():
		exit_seek_cover()
		return

	direction = navmesh.get_simple_path(translation, destination.translation)[1] - translation
	direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, randf()*rotationThreshold*2 - rotationThreshold)
	moving = true
	running = true

func enter_seek_cover():
	if room != null:
		var tries = 0
		while destination == null or near_cover_destination():
			if tries >= 3:
				destination = null
				break

			var waypoints = room.get_covers()
			destination = waypoints[randi() % waypoints.size()]
			tries += 1

func exit_seek_cover():
	currentState = NPCState.Cover
	stateTimer = 0

func handle_cover(delta):
	moving = false
	running = false
	crouching = false
	strafing = false

	if lastState != currentState:
		enter_cover()
	lastState = currentState

	if stateTimer >= stateMaxTime:
		exit_cover()
		return
	stateTimer += delta

	strafing = true
	crouching = true

func enter_cover():
	stateTimer = 0
	stateMaxTime = randf() * (maxCover - minCover) + minCover

func exit_cover():
	var exit_states = [NPCState.Chase, NPCState.Strafe, NPCState.SeekCover, NPCState.StandCover]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_stand_cover(delta):
	moving = false
	running = false
	strafing = false

	if lastState != currentState:
		enter_stand_cover()
	lastState = currentState

	if stateTimer >= stateMaxTime:
		exit_stand_cover()
		return
	stateTimer += delta

	strafing = true

func enter_stand_cover():
	stateTimer = 0
	stateMaxTime = randf() * (maxCover - minCover) + minCover

func exit_stand_cover():
	var exit_states = [NPCState.Chase, NPCState.Strafe, NPCState.SeekCover, NPCState.Cover]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_punch(delta):
	moving = false
	running = false
	strafing = false
	punching = false

	if lastState != currentState:
		enter_punch()
	lastState = currentState

	if stateTimer >= dealDamageDelay and not dealtDamage and can_melee_player():
		player.take_damage(kickDamage)
		dealtDamage = true

	if stateTimer >= stateMaxTime:
		exit_punch()
		return
	stateTimer += delta

	strafing = true
	punching = true
	moving = true

func enter_punch():
	dealtDamage = false
	stateTimer = 0
	stateMaxTime = punchTime

func exit_punch():
	var exit_states = [NPCState.Chase]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_kick(delta):
	moving = false
	running = false
	strafing = false
	kicking = false

	if lastState != currentState:
		enter_kick()
	lastState = currentState

	if stateTimer >= dealDamageDelay and not dealtDamage and can_melee_player():
		player.take_damage(kickDamage)
		dealtDamage = true

	if stateTimer >= stateMaxTime:
		exit_kick()
		return
	stateTimer += delta

	strafing = true
	kicking = true
	moving = true

func enter_kick():
	dealtDamage = false
	stateTimer = 0
	stateMaxTime = kickTime

func exit_kick():
	var exit_states = [NPCState.Chase]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_strafe(delta):
	moving = false
	running = false
	crouching = false

	if lastState != currentState:
		enter_strafe()
	lastState = currentState

	if destination == null:
		exit_strafe()
		return

	if near_destination():
		exit_strafe()
		return

	var tra = translation
	var pra = player.translation
	var rra = room.translation

	direction = navmesh.get_simple_path(translation, destination.translation)[1] - translation
	direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, randf()*rotationThreshold*2 - rotationThreshold)
	moving = true

func enter_strafe():
	strafing = true
	if room != null:
		var tries = 0
		while destination == null or near_destination():
			if tries >= 3:
				destination = null
				break

			var waypoints = room.get_waypoints()
			destination = waypoints[randi() % waypoints.size()]
			tries += 1

func exit_strafe():
	strafing = false
	var exit_states = [NPCState.Chase, NPCState.Strafe, NPCState.SeekCover]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_chase(delta):
	moving = false
	running = false
	crouching = false

	if lastState != currentState:
		enter_chase()
		lastState = currentState
		return

	if can_melee_player():
		exit_chase_with_melee()
		return

	if stateTimer >= stateMaxTime:
		exit_chase()
		return
	stateTimer += delta

	var tra = translation
	var pra = player.translation
	var rra = room.translation

	direction = navmesh.get_simple_path(translation, player.global_transform.origin - room.global_transform.origin)[1] - translation
	direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, randf()*rotationThreshold*2 - rotationThreshold)
	moving = true
	running = true

func enter_chase():
	stateTimer = 0
	stateMaxTime = randf() * (maxChase - minChase) + minChase

func exit_chase():
	var exit_states = [NPCState.Chase, NPCState.Strafe, NPCState.SeekCover]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func exit_chase_with_melee():
	var exit_states = [NPCState.Punch, NPCState.Kick]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_stand(delta):
	if lastState != currentState:
		enter_stand()
	lastState = currentState

	if react_to_player(delta):
		return

	if stateTimer >= stateMaxTime:
		exit_stand()

	stateTimer += delta

func enter_stand():
	stateTimer = 0
	stateMaxTime = randf() * (maxStand - minStand) + minStand

func exit_stand():
	var exit_states = [NPCState.Stand, NPCState.Patrol]
	currentState = exit_states[randi() % exit_states.size()]
	stateTimer = 0

func handle_alert(delta):
	if lastState != currentState:
		enter_alert()
	lastState = currentState

	if stateTimer >= stateMaxTime:
		exit_alert()
		return

	stateTimer += delta

func enter_alert():
	stateTimer = 0
	stateMaxTime = alertTime
	alerted = true
	emit_signal("npc_alert", self)

func exit_alert():
	var exit_states = [NPCState.Chase, NPCState.Strafe, NPCState.SeekCover]
	currentState = exit_states[randi() % exit_states.size()]
	alerted = false
	stateTimer = 0

func derive_animation_state():
	var move_animation = PlayerMovementAnimations.IDLE
	var interact_animation = PlayerInteractionAnimations.IDLE

	if is_alive():
		if alerted:
			move_animation = PlayerMovementAnimations.ATTACK
		elif crouching:
			move_animation = PlayerMovementAnimations.CROUCH
		elif punching:
			move_animation = PlayerMovementAnimations.PUNCH
		elif kicking:
			move_animation = PlayerMovementAnimations.KICK
		elif moving and running:
			move_animation = PlayerMovementAnimations.RUN
		elif moving:
			move_animation = PlayerMovementAnimations.WALK
		else:
			move_animation = PlayerMovementAnimations.IDLE

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

func disable():
	alerted = false
	moving = false
	running = false
	crouching = false
	punching = false
	kicking = false
	weapon.end_shoot()
	currentState = NPCState.None
