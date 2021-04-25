extends Node

func _ready():
	find_parent("Room").add_cover(self)

func blocks_object(obj):
	return false
