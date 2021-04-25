extends Spatial

var shooting = false

func begin_shoot():
	# For now, shoot all the time
	if not shooting:
		shooting = true

func end_shoot():
	shooting = false

func _ready():
	pass
