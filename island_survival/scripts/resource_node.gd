extends StaticBody2D
class_name ResourceNode

@export_enum("wood", "stone", "food") var resource_type: String = "wood"
@export var max_durability: float = 3.0
@export var yield_amount: int = 3
@export var respawn_time: float = 25.0

var current_durability: float = 3.0
var is_depleted: bool = false

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_durability = max_durability
	update_visual_type()

func update_visual_type() -> void:
	# Hide all sub-visuals and show the active resource visual
	if visual.has_node("TreeVisual"):
		visual.get_node("TreeVisual").visible = (resource_type == "wood")
	if visual.has_node("StoneVisual"):
		visual.get_node("StoneVisual").visible = (resource_type == "stone")
	if visual.has_node("BushVisual"):
		visual.get_node("BushVisual").visible = (resource_type == "food")

func harvest(harvester: Player, multiplier: float = 1.0) -> void:
	if is_depleted:
		return

	current_durability -= 1.0
	
	# Wobble effect
	var tween = create_tween()
	tween.tween_property(visual, "rotation_degrees", 8.0, 0.05)
	tween.tween_property(visual, "rotation_degrees", -8.0, 0.05)
	tween.tween_property(visual, "rotation_degrees", 0.0, 0.05)

	if current_durability <= 0:
		deplete(harvester, multiplier)

func deplete(harvester: Player, multiplier: float) -> void:
	is_depleted = true
	var final_amount = int(round(yield_amount * multiplier))
	harvester.add_resource(resource_type, final_amount)

	# Hide visual and disable collision
	visual.visible = false
	collision_shape.disabled = true

	# Start respawn timer
	get_tree().create_timer(respawn_time).timeout.connect(_on_respawn_timeout)

func _on_respawn_timeout() -> void:
	current_durability = max_durability
	is_depleted = false
	visual.visible = true
	collision_shape.disabled = false
	update_visual_type()
