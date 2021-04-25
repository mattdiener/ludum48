extends Spatial

enum Type { Patrol, Boss, Idle }
enum Style { Alien, Animal, Military, Robot, Zombie }
enum NPCState { Patrol, Stand, Chase, Cover, Punch, Kick, Strafe }

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

export(Type) var type
export(NodePath) var roomPath
export(Style) var style

onready var room = get_node(roomPath) 
onready var mesh = get_node("Root/Skeleton/characterLargeMale")
onready var character_animation = get_node("AnimationTree")
onready var character = self

var currentState : int = NPCState.Stand
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

# Called when the node enters the scene tree for the first time.
func _ready():
	var material_res = NPC_MATERIALS[style][randi() % NPC_MATERIALS[style].size()]
	var material = ResourceLoader.load(material_res)
	mesh["material/0"] = material
	character_animation.set("parameters/Transition/current", PlayerAnimations.IDLE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Do different control based on state
	if currentState == NPCState.Patrol:
		pass
	elif currentState == NPCState.Stand:
		pass
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
	
	derive_animation_state()
	
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
	
