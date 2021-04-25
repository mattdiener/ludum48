extends Spatial

const FLOOR_HEIGHT = 0.75

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

func get_aabb() -> AABB:
	var mesh: MeshInstance = find_node("RoomMesh");
	return mesh.get_aabb();

func get_center() -> Vector3:
	var position = translation
	var size = get_aabb().size
	return Vector3(
		position.x + (size.x / 2),
		position.y + (size.y / 2),
		position.z + (size.z / 2)
	)

func get_diagonal_len() -> float:
	var aabb = get_aabb()
	return translation.distance_to(translation + aabb.end)

func left_of(exit_position: Vector3) -> Vector3:
	var aabb = get_aabb()
	var ofs = Vector3(exit_position.x, -FLOOR_HEIGHT, aabb.size.z)
	return translation + ofs

func right_of(exit_position: Vector3) -> Vector3:
	var aabb = get_aabb()
	var ofs = Vector3(aabb.size.x, -FLOOR_HEIGHT, exit_position.z)
	return translation + ofs
