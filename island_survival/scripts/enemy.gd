extends CharacterBody2D
class_name NightWolf

@export var move_speed: float = 140.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var max_health: float = 40.0

var health: float = 40.0
var can_attack: bool = true
var target_player: Player = null
var nearby_campfire: Node2D = null

var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var sprite_poly: Polygon2D = $Visual/BodyPolygon

enum State { WANDER, CHASE, FLEE }
var current_state: State = State.WANDER

func _ready() -> void:
	health = max_health
	pick_random_wander()

func pick_random_wander() -> void:
	var angle = randf() * TAU
	wander_direction = Vector2(cos(angle), sin(angle))
	wander_timer = randf_range(2.0, 4.0)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	# Check for campfire fear
	check_campfires()

	match current_state:
		State.WANDER:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_random_wander()
			velocity = wander_direction * (move_speed * 0.4)
			
			if target_player != null:
				current_state = State.CHASE

		State.CHASE:
			if target_player != null and is_instance_valid(target_player):
				var dir = (target_player.global_position - global_position).normalized()
				velocity = dir * move_speed
				$Visual.rotation = dir.angle()
				
				# Try attack player if inside attack area
				if attack_area.overlaps_body(target_player) and can_attack:
					perform_attack()
			else:
				current_state = State.WANDER

		State.FLEE:
			if nearby_campfire != null and is_instance_valid(nearby_campfire):
				var run_away_dir = (global_position - nearby_campfire.global_position).normalized()
				velocity = run_away_dir * (move_speed * 1.2)
				$Visual.rotation = run_away_dir.angle()
			else:
				current_state = State.WANDER

	move_and_slide()

func check_campfires() -> void:
	# Scan for lit campfires in detection area
	var areas = detection_area.get_overlapping_areas()
	var found_fire: Node2D = null
	for a in areas:
		if a.is_in_group("campfire_heat"):
			found_fire = a
			break
	
	if found_fire:
		nearby_campfire = found_fire
		current_state = State.FLEE
	elif current_state == State.FLEE:
		nearby_campfire = null
		current_state = State.CHASE if target_player else State.WANDER

func perform_attack() -> void:
	if target_player != null and is_instance_valid(target_player) and can_attack:
		target_player.take_damage(attack_damage)
		can_attack = false
		get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

func take_damage(amount: float) -> void:
	health -= amount
	
	# Flash red
	var tween = create_tween()
	sprite_poly.modulate = Color(2.0, 0.2, 0.2)
	tween.tween_property(sprite_poly, "modulate", Color(1, 1, 1), 0.15)

	if health <= 0:
		die()

func die() -> void:
	# Drop food for player when wolf is killed
	if target_player != null and is_instance_valid(target_player):
		target_player.add_resource("food", randi_range(2, 4))
		target_player.emit_signal("notification_requested", "Defeated Wolf! (+Meat)")
	queue_free()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		target_player = body
		if current_state != State.FLEE:
			current_state = State.CHASE

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		if current_state == State.CHASE:
			current_state = State.WANDER
