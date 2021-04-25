extends Node

func _ready():
	find_parent("Room").add_waypoint(self)
