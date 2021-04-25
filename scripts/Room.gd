extends Spatial

const FLOOR_HEIGHT = 0.75

var player = null

var covers = []
var spawnpoints = []
var waypoints = []

func init(player):
	self.player = player

func _ready():
	traverseNodes(self)
	addRandomNPC()
	addRandomNPC()

func _process(delta):
	pass

func addRandomNPC():
	if len(spawnpoints) == 0:
		print("No spawnpoints!")
		return
		
	var spawnpoint = spawnpoints[randi() % spawnpoints.size()]
	var npc_resource = load("res://NPC.tscn")
	var npc = npc_resource.instance()
	npc.init(0, self, player, randi() % 5)
	npc.translation = spawnpoint.translation
	add_child(npc)

func traverseNodes(node):
	var nodeClass = node.get_class()
	
	if "type" in node:
		if node.type == "Spawnpoint":
			add_spawnpoint(node)
		if node.type == "Waypoint":
			add_waypoint(node)
		if node.type == "Cover":
			add_cover(node)
	
	if node.get_child_count() == 0:
		return
	
	for N in node.get_children():
		traverseNodes(N)

func get_navmesh():
	return get_node("Navigation")

func add_spawnpoint(waypoint):
	spawnpoints.append(waypoint)

func add_waypoint(waypoint):
	waypoints.append(waypoint)
	
func add_cover(cover):
	covers.append(cover)

func get_spawnpoints():
	return spawnpoints
	
func get_waypoints():
	return waypoints
	
func get_covers():
	return covers

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
