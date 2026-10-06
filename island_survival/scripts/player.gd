extends CharacterBody2D
class_name Player

signal health_changed(current_hp, max_hp)
signal hunger_changed(current_hunger, max_hunger)
signal inventory_changed(inventory)
signal player_died
signal notification_requested(text)

@export var move_speed: float = 200.0
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0

var health: float = 100.0
var hunger: float = 100.0
var hunger_drain_rate: float = 0.8 # per second

var inventory: Dictionary = {
	"wood": 10,  # starter wood
	"stone": 5,  # starter stone
	"food": 3    # starter food
}

var tools: Dictionary = {
	"axe": false,
	"pickaxe": false,
	"sword": false
}

var active_tool: String = "none"
var placing_building_type: String = "" # "campfire" or "shelter"

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite_poly: Polygon2D = $Visual/BodyPolygon
@onready var torch_light: PointLight2D = $TorchLight

func _ready() -> void:
	health = max_health
	hunger = max_hunger
	emit_signal("health_changed", health, max_health)
	emit_signal("hunger_changed", hunger, max_hunger)
	emit_signal("inventory_changed", inventory)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	# Handle 2D movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1

	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	move_and_slide()

	# Rotate visual towards mouse direction or movement direction
	var mouse_pos = get_global_mouse_position()
	var look_angle = (mouse_pos - global_position).angle()
	$Visual.rotation = look_angle

func _process(delta: float) -> void:
	if health <= 0:
		return

	# Deplete hunger slowly over time
	hunger = max(0.0, hunger - hunger_drain_rate * delta)
	emit_signal("hunger_changed", hunger, max_hunger)

	# If starving, take damage over time
	if hunger <= 0:
		take_damage(2.0 * delta)

	# Action inputs
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if placing_building_type != "":
			try_place_building()
		else:
			perform_harvest_or_attack()

	if Input.is_key_pressed(KEY_E):
		eat_food()

func perform_harvest_or_attack() -> void:
	var bodies = interaction_area.get_overlapping_bodies()
	var areas = interaction_area.get_overlapping_areas()

	# Combine overlaps
	var targets = []
	for b in bodies:
		if b != self:
			targets.append(b)
	for a in areas:
		targets.append(a)

	var hit_something = false
	for target in targets:
		if target.has_method("harvest"):
			var yield_bonus = 1.0
			if tools["axe"] and target.resource_type == "wood":
				yield_bonus = 2.0
			elif tools["pickaxe"] and target.resource_type == "stone":
				yield_bonus = 2.0
			
			target.harvest(self, yield_bonus)
			hit_something = true
			break
		elif target.has_method("take_damage") and target != self:
			var dmg = 15.0
			if tools["sword"]:
				dmg = 35.0
			target.take_damage(dmg)
			hit_something = true
			break
		elif target.has_method("interact_shelter"):
			target.interact_shelter(self)
			hit_something = true
			break

func add_resource(res_type: String, amount: int) -> void:
	if inventory.has(res_type):
		inventory[res_type] += amount
	else:
		inventory[res_type] = amount
	emit_signal("inventory_changed", inventory)
	emit_signal("notification_requested", "+%d %s" % [amount, res_type.capitalize()])

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	
	# Flash red on hit
	var tween = create_tween()
	sprite_poly.modulate = Color(1.5, 0.4, 0.4)
	tween.tween_property(sprite_poly, "modulate", Color(1, 1, 1), 0.2)

	if health <= 0:
		emit_signal("player_died")

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	emit_signal("health_changed", health, max_health)

func eat_food() -> void:
	if inventory.get("food", 0) > 0:
		if hunger < max_hunger or health < max_health:
			inventory["food"] -= 1
			hunger = min(max_hunger, hunger + 35.0)
			heal(15.0)
			emit_signal("hunger_changed", hunger, max_hunger)
			emit_signal("inventory_changed", inventory)
			emit_signal("notification_requested", "Ate Food (+35 Hunger, +15 HP)")

func craft_item(item_name: String) -> bool:
	var success = false
	match item_name:
		"campfire":
			if inventory.get("wood", 0) >= 5 and inventory.get("stone", 0) >= 3:
				inventory["wood"] -= 5
				inventory["stone"] -= 3
				placing_building_type = "campfire"
				success = true
		"shelter":
			if inventory.get("wood", 0) >= 15 and inventory.get("stone", 0) >= 10:
				inventory["wood"] -= 15
				inventory["stone"] -= 10
				placing_building_type = "shelter"
				success = true
		"axe":
			if inventory.get("wood", 0) >= 5 and not tools["axe"]:
				inventory["wood"] -= 5
				tools["axe"] = true
				active_tool = "axe"
				success = true
		"pickaxe":
			if inventory.get("wood", 0) >= 5 and inventory.get("stone", 0) >= 5 and not tools["pickaxe"]:
				inventory["wood"] -= 5
				inventory["stone"] -= 5
				tools["pickaxe"] = true
				active_tool = "pickaxe"
				success = true
		"sword":
			if inventory.get("wood", 0) >= 10 and inventory.get("stone", 0) >= 10 and not tools["sword"]:
				inventory["wood"] -= 10
				inventory["stone"] -= 10
				tools["sword"] = true
				active_tool = "sword"
				success = true

	if success:
		emit_signal("inventory_changed", inventory)
		if placing_building_type != "":
			emit_signal("notification_requested", "Click on the ground to place " + item_name.capitalize())
		else:
			emit_signal("notification_requested", "Crafted " + item_name.capitalize())
	else:
		emit_signal("notification_requested", "Not enough resources!")
	
	return success

func try_place_building() -> void:
	if placing_building_type == "":
		return
	
	var build_pos = get_global_mouse_position()
	# Ensure building placement isn't too far from player
	if global_position.distance_to(build_pos) > 250.0:
		emit_signal("notification_requested", "Too far to build!")
		return

	get_parent().spawn_building(placing_building_type, build_pos)
	emit_signal("notification_requested", "Placed " + placing_building_type.capitalize())
	placing_building_type = ""
