extends Spatial

const FLOOR_HEIGHT = 0.75

onready var loaded_rooms = get_node("LoadedRooms")
var active_room = null

func get_active_navmesh():
	if not active_room:
		return null
	return active_room.get_node("Navigation")

func load_room(room_path: String, position: Vector3):
	var room_resource = load(room_path)
	var room_scene = room_resource.instance()

	room_scene.translation = position
	add_child_below_node(loaded_rooms, room_scene)
	return room_scene

func get_room_aabb(room: Spatial) -> AABB:
	var mesh: MeshInstance = room.find_node("RoomMesh");
	return mesh.get_aabb();

func left_of(parent_room: Spatial) -> Vector3:
	var aabb = get_room_aabb(parent_room)
	return Vector3(0, -FLOOR_HEIGHT, aabb.size.z)

func right_of(parent_room: Spatial) -> Vector3:
	var aabb = get_room_aabb(parent_room)
	return Vector3(aabb.size.x, -FLOOR_HEIGHT, 0)

func _ready():
	var room1 = load_room("res://rooms/Room1.tscn", Vector3.ZERO)
	var room2 = load_room("res://rooms/Room2.tscn", left_of(room1))
	var room3 = load_room("res://rooms/Room1.tscn", right_of(room1))
	
	active_room = room1
