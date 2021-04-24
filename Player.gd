extends KinematicBody

var moveSpeed = 3.0
var velocity = Vector3.ZERO

onready var nav_mesh = get_node("../Room/Navigation")

func get_input():
	var input = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input.x -= 1
		input.z -= 1
	if Input.is_action_pressed("move_backward"):
		input.x += 1
		input.z += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
		input.z += 1
	if Input.is_action_pressed("move_right"):
		input.x += 1
		input.z -= 1
	
	return input.normalized()
	

func _physics_process(delta):	
	var input = get_input()
	var direction = ((transform.basis.z * input.z) + (transform.basis.x * input.x))
	
	velocity.x = direction.x * moveSpeed
	velocity.z = direction.z * moveSpeed
	
	move_and_collide(velocity * delta)

	translation = nav_mesh.get_closest_point(translation)


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
