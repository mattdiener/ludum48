extends Area

signal exited_left(exit_position)
signal exited_right(exit_position)

func _on_entered(_body: Node):
	emit_signal("exited_right", $Shape.translation)

func _ready():
	connect("body_entered", self, "_on_entered")
