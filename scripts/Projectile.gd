extends KinematicBody

const MOVE_SPEED = 20
const RANGE = 10

var velocity = Vector3.ZERO
var start_position = Vector3.ZERO

func init(direction: Vector3):
	velocity = direction * MOVE_SPEED

func _physics_process(delta):
	if start_position.distance_to(translation) > RANGE:
		self.queue_free()

	move_and_collide(velocity * delta)

func _ready():
	start_position = translation
