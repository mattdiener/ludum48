extends MarginContainer

func _process(delta):
	if get_tree().paused:
		self.show()
	else:
		self.hide()
