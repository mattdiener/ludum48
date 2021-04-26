extends MarginContainer

onready var health_bar = get_node("VBoxContainer/HealthBar")
onready var tween = get_node("VBoxContainer/HealthBar/Tween")
var npc = null

func init(npc, maxHealth):
	self.npc = npc
	npc.connect("health_change", self, "_on_health_change")

func _on_health_change(new_hp):
	if new_hp > 0:
		update_visibility(new_hp)
	if health_bar:
		tween.interpolate_property(
			health_bar,
			"value",
			health_bar.value,
			new_hp,
			0.25,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
		tween.interpolate_callback(
			self,
			0.1,
			"update_visibility",
			new_hp)
		tween.start()

func update_visibility(new_hp):
	if new_hp > 0:
		show()
	else:
		hide()
		

# Called when the node enters the scene tree for the first time.
func _ready():
	hide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
