extends Area

signal exited_left(exit_position)
signal exited_right(exit_position)

func _on_entered(body: Node):
	if "is_player" in body and body.is_player and body.is_alive():
		emit_signal("exited_right", $Shape.translation)

func _ready():
	connect("body_entered", self, "_on_entered")
