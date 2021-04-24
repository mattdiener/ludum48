extends Spatial

enum Type { Patrol, Boss, Idle }
enum Style { Robot, }
enum NPCState { Patrol, Stand, Chase, Cover, Punch, Kick, Strafe }

export(Type) var type
export(NodePath) var levelPath
onready var level = get_node(levelPath) 

onready var mesh = get_node("Root/Skeleton/characterLargeMale")

var currentState : int = NPCState.Stand

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var material = ResourceLoader.load("res://res/material/cyborg.tres")
	mesh["material/0"] = material
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
