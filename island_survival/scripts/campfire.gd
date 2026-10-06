extends StaticBody2D
class_name Campfire

@export var max_fuel_time: float = 60.0 # Campfire lasts 60 seconds
var fuel_time: float = 60.0

@onready var light: PointLight2D = $PointLight2D
@onready var heat_area: Area2D = $HeatArea
@onready var flame_poly: Polygon2D = $Visual/FlamePolygon

func _ready() -> void:
	fuel_time = max_fuel_time
	heat_area.add_to_group("campfire_heat")

func _process(delta: float) -> void:
	fuel_time -= delta
	
	if fuel_time > 0:
		# Flicker light
		light.energy = randf_range(1.2, 1.6)
		flame_poly.scale = Vector2.ONE * randf_range(0.9, 1.1)
		
		# Burn any enemies touching the campfire core
		var bodies = heat_area.get_overlapping_bodies()
		for b in bodies:
			if b is NightWolf and b.has_method("take_damage"):
				b.take_damage(10.0 * delta)
	else:
		# Fire burned out
		light.energy = 0.0
		flame_poly.visible = false
		heat_area.remove_from_group("campfire_heat")

func refuel(wood_amount: int) -> void:
	fuel_time = min(max_fuel_time, fuel_time + wood_amount * 15.0)
	light.energy = 1.4
	flame_poly.visible = true
	if not heat_area.is_in_group("campfire_heat"):
		heat_area.add_to_group("campfire_heat")
