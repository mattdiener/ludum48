extends Spatial

const FLOOR_HEIGHT = 0.75
const EXIT_LIGHT_RANGE = 1.25
const EXIT_LIGHT_ENERGY = 2
const EXIT_LIGHT_COLOR = Color(255, 0, 0)

onready var exits = get_node("Exits").get_children()
var exit_lights = []
var light_tween = null

var player = null
var alert_npc_count = 0

var difficulty = 0
var covers = []
var spawnpoints = []
var waypoints = []
var npcs = []

func init(player, difficulty):
	self.player = player
	self.difficulty = difficulty

func _ready():
	for exit in exits:
		var exit_shape = exit.get_node("Shape")

		var light = OmniLight.new()
		light.omni_range = 0
		light.light_energy = EXIT_LIGHT_ENERGY
		light.light_color = EXIT_LIGHT_COLOR

		exit_shape.add_child(light)
		exit_lights.push_back(light)

	traverseNodes(self)
	add_npcs()

	light_tween = Tween.new()
	add_child(light_tween)

func _process(delta):
	pass

func is_alert():
	return alert_npc_count > 0

func _on_npc_alert(_npc):
	if not is_alert():
		fade_exit_light(EXIT_LIGHT_RANGE)

	alert_npc_count += 1

func _on_npc_unalert(_npc):
	alert_npc_count -= 1

	if not is_alert():
		fade_exit_light(0)

func fade_exit_light(target: float):
	for light in exit_lights:
		light_tween.interpolate_property(
			light,
			"omni_range",
			light.omni_range,
			target,
			1,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
	light_tween.start()

func add_npcs():
	var style = randi() % 5
	var max_npcs = min(difficulty, spawnpoints.size())
	if max_npcs == 0:
		return

	var num_npcs = (randi() % max_npcs) + 1
	var npc_difficulty = floor(difficulty / num_npcs)
	var npc_remainder = difficulty % num_npcs

	var i = 0
	while i < num_npcs:
		if i < npc_remainder:
			addNPC(style, npc_difficulty+1)
		else:
			addNPC(style, npc_difficulty)
		i += 1

func addNPC(style, difficulty):
	if len(spawnpoints) == 0:
		print("No spawnpoints!")
		return

	var idx = randi() % spawnpoints.size()
	var spawnpoint = spawnpoints[idx]
	spawnpoints[idx] = spawnpoints[spawnpoints.size()-1]
	spawnpoints.remove((spawnpoints.size()-1))

	var npc_resource = load("res://NPC.tscn")
	var npc = npc_resource.instance()
	npc.init(0, self, player, style)
	npc.translation = spawnpoint.translation
	npc.connect("npc_alert", self, "_on_npc_alert")
	npc.connect("npc_unalert", self, "_on_npc_unalert")

	add_child(npc)
	npcs.push_back(npc)

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

func disable():
	# Prevents trying to fade non-existent lights
	exit_lights = []
	for npc in npcs:
		npc.disable()
