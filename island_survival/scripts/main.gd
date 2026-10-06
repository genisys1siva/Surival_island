extends Node2D

@export var day_duration: float = 90.0 # 90 seconds per day cycle
var time_of_day: float = 0.0 # 0.0 = Morning, 0.25 = Noon, 0.5 = Sunset, 0.75 = Midnight
var current_day: int = 1
var is_night: bool = false

# Preloads for scenes
var campfire_scene = preload("res://scenes/campfire.tscn")
var shelter_scene = preload("res://scenes/shelter.tscn")
var enemy_scene = preload("res://scenes/enemy.tscn")
var resource_scene = preload("res://scenes/resource_node.tscn")

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var player: Player = $Player
@onready var ui: CanvasLayer = $UI
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var buildings_container: Node2D = $BuildingsContainer
@onready var resources_container: Node2D = $ResourcesContainer

# Canvas modulate color gradient points
var day_color: Color = Color(1.0, 1.0, 1.0)
var sunset_color: Color = Color(0.9, 0.6, 0.4)
var night_color: Color = Color(0.15, 0.18, 0.35)
var dawn_color: Color = Color(0.8, 0.7, 0.6)

func _ready() -> void:
	# Connect player signals
	player.player_died.connect(_on_player_died)
	player.notification_requested.connect(_on_notification_requested)

	# Initial spawn of island resources
	spawn_initial_island_resources()
	
	# Initial UI sync
	ui.update_day_info(current_day, time_of_day)

func _process(delta: float) -> void:
	# Advance time of day
	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		current_day += 1
		_on_notification_requested("Day %d Survived!" % current_day)

	# Update lighting tint based on time of day
	update_lighting()

	# Check night transitions
	var was_night = is_night
	is_night = (time_of_day >= 0.5 and time_of_day <= 0.9)

	if is_night and not was_night:
		_on_night_started()
	elif not is_night and was_night:
		_on_dawn_started()

	# Update UI clock
	ui.update_day_info(current_day, time_of_day)

func update_lighting() -> void:
	# 0.0 to 0.4: Day
	# 0.4 to 0.5: Sunset transition
	# 0.5 to 0.85: Night
	# 0.85 to 1.0: Dawn transition
	var current_color: Color
	if time_of_day < 0.4:
		current_color = day_color
	elif time_of_day < 0.5:
		var t = (time_of_day - 0.4) / 0.1
		current_color = day_color.lerp(sunset_color, t)
	elif time_of_day < 0.85:
		var t = (time_of_day - 0.5) / 0.1
		current_color = sunset_color.lerp(night_color, min(1.0, t))
	else:
		var t = (time_of_day - 0.85) / 0.15
		current_color = night_color.lerp(dawn_color, t)

	canvas_modulate.color = current_color

func _on_night_started() -> void:
	_on_notification_requested("⚠️ Night has fallen! Beware of wolves!")
	spawn_night_enemies()

func _on_dawn_started() -> void:
	_on_notification_requested("☀️ Morning light arrives! You survived the night.")
	clear_night_enemies()

func spawn_night_enemies() -> void:
	# Spawn wolves based on current day count (min 2, max 8)
	var spawn_count = min(8, 2 + current_day)
	for i in range(spawn_count):
		var angle = randf() * TAU
		var distance = randf_range(400.0, 700.0)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		var enemy_inst = enemy_scene.instantiate()
		enemy_inst.global_position = spawn_pos
		enemies_container.add_child(enemy_inst)

func clear_night_enemies() -> void:
	for enemy in enemies_container.get_children():
		var tween = create_tween()
		tween.tween_property(enemy, "modulate:a", 0.0, 1.0)
		tween.tween_callback(enemy.queue_free)

func skip_to_dawn() -> void:
	time_of_day = 0.95
	update_lighting()

func spawn_building(type_name: String, pos: Vector2) -> void:
	var b_inst: Node2D = null
	if type_name == "campfire":
		b_inst = campfire_scene.instantiate()
	elif type_name == "shelter":
		b_inst = shelter_scene.instantiate()

	if b_inst:
		b_inst.global_position = pos
		buildings_container.add_child(b_inst)

func spawn_initial_island_resources() -> void:
	# Randomly scatter trees, stones, and berry bushes around center island
	var types = ["wood", "wood", "stone", "stone", "food"]
	for i in range(35):
		var angle = randf() * TAU
		var radius = randf_range(80.0, 600.0)
		var pos = Vector2(cos(angle), sin(angle)) * radius

		var res_inst = resource_scene.instantiate()
		res_inst.global_position = pos
		res_inst.resource_type = types[i % types.size()]
		resources_container.add_child(res_inst)

func _on_player_died() -> void:
	ui.show_game_over(current_day)

func _on_notification_requested(msg: String) -> void:
	ui.show_notification(msg)

func restart_game() -> void:
	get_tree().reload_current_scene()
