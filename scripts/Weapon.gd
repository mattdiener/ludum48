extends Spatial

onready var shoot_timer = get_node("ShootTimer")

# Whether the trigger is held
var shooting = false
var parent = null
var isAuto = true

func begin_shoot():
	# Don't trigger another shot if the trigger is held
	# Don't trigger another shot if a shot is in progress
	if not shooting and shoot_timer.is_stopped():
		shooting = true
		shoot_timer.start()

func _on_fire_projectile():
	shoot_timer.stop()

	var projectile_resource = load("res://Projectile.tscn")
	var projectile = projectile_resource.instance()
	projectile.translation = Vector3(
		global_transform.origin.x,
		global_transform.origin.y,
		global_transform.origin.z
	)
	if parent:
		projectile.init(parent.get_look_direction())
		get_tree().get_root().add_child(projectile)
	else:
		projectile.queue_free()
	
	if isAuto:
		shoot_timer.start()

func bind_parent(parent):
	self.parent = parent

func end_shoot():
	shooting = false
	if not shoot_timer.is_stopped():
		shoot_timer.stop()

func _ready():
	shoot_timer.connect("timeout", self, "_on_fire_projectile")
