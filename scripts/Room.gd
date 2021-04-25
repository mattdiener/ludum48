extends Node

var waypoints = []
var covers = []

func _ready():
	pass # Replace with function body.

func _process(delta):
	pass

func get_navmesh():
	return get_node("Navigation")

func add_waypoint(waypoint):
	waypoints.append(waypoint)
	
func add_cover(cover):
	covers.append(cover)
