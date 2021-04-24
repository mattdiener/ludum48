extends Area

signal exited_left(exit_position)
signal exited_right(exit_position)

func _on_entered(body: Node):
	emit_signal("exited_left", $Shape.translation)

func _ready():
	connect("body_entered", self, "_on_entered")
