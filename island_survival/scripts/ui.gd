extends CanvasLayer

@onready var health_bar: ProgressBar = $HUD/VBoxStats/HealthBar
@onready var hunger_bar: ProgressBar = $HUD/VBoxStats/HungerBar
@onready var wood_label: Label = $HUD/HBoxInventory/WoodCount
@onready var stone_label: Label = $HUD/HBoxInventory/StoneCount
@onready var food_label: Label = $HUD/HBoxInventory/FoodCount

@onready var day_label: Label = $HUD/VBoxTime/DayLabel
@onready var clock_label: Label = $HUD/VBoxTime/ClockLabel

@onready var crafting_panel: PanelContainer = $CraftingPanel
@onready var craft_btn_toggle: Button = $HUD/CraftToggleBtn
@onready var notification_label: Label = $NotificationLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var days_survived_label: Label = $GameOverPanel/VBox/DaysSurvivedLabel
@onready var restart_button: Button = $GameOverPanel/VBox/RestartBtn

@onready var craft_campfire_btn: Button = $CraftingPanel/VBox/CraftCampfireBtn
@onready var craft_shelter_btn: Button = $CraftingPanel/VBox/CraftShelterBtn
@onready var craft_axe_btn: Button = $CraftingPanel/VBox/CraftAxeBtn
@onready var craft_pickaxe_btn: Button = $CraftingPanel/VBox/CraftPickaxeBtn
@onready var craft_sword_btn: Button = $CraftingPanel/VBox/CraftSwordBtn

var player_ref: Player = null
var notif_tween: Tween = null

func _ready() -> void:
	crafting_panel.visible = false
	game_over_panel.visible = false
	notification_label.modulate.a = 0.0

	craft_btn_toggle.pressed.connect(toggle_crafting_panel)
	restart_button.pressed.connect(_on_restart_pressed)

	craft_campfire_btn.pressed.connect(func(): _on_craft_request("campfire"))
	craft_shelter_btn.pressed.connect(func(): _on_craft_request("shelter"))
	craft_axe_btn.pressed.connect(func(): _on_craft_request("axe"))
	craft_pickaxe_btn.pressed.connect(func(): _on_craft_request("pickaxe"))
	craft_sword_btn.pressed.connect(func(): _on_craft_request("sword"))

	# Connect player signals after main ready
	call_deferred("bind_player_signals")

func bind_player_signals() -> void:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("Player"):
		player_ref = main_scene.get_node("Player")
		player_ref.health_changed.connect(_on_player_health_changed)
		player_ref.hunger_changed.connect(_on_player_hunger_changed)
		player_ref.inventory_changed.connect(_on_player_inventory_changed)
		_on_player_inventory_changed(player_ref.inventory)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C:
			toggle_crafting_panel()

func toggle_crafting_panel() -> void:
	crafting_panel.visible = not crafting_panel.visible

func _on_craft_request(item_name: String) -> void:
	if player_ref:
		player_ref.craft_item(item_name)
		crafting_panel.visible = false

func _on_player_health_changed(hp: float, max_hp: float) -> void:
	health_bar.value = (hp / max_hp) * 100.0

func _on_player_hunger_changed(hunger: float, max_hunger: float) -> void:
	hunger_bar.value = (hunger / max_hunger) * 100.0

func _on_player_inventory_changed(inventory: Dictionary) -> void:
	wood_label.text = "Wood: %d" % inventory.get("wood", 0)
	stone_label.text = "Stone: %d" % inventory.get("stone", 0)
	food_label.text = "Food: %d" % inventory.get("food", 0)

func update_day_info(day: int, time_val: float) -> void:
	day_label.text = "DAY %d" % day
	
	# Convert 0.0-1.0 time to 24hr format string
	var total_minutes = int(time_val * 1440.0) # 24 * 60
	var hours = (total_minutes / 60) % 24
	var minutes = total_minutes % 60
	clock_label.text = "%02d:%02d" % [hours, minutes]

func show_notification(text: String) -> void:
	notification_label.text = text
	notification_label.modulate.a = 1.0
	
	if notif_tween and notif_tween.is_running():
		notif_tween.kill()

	notif_tween = create_tween()
	notif_tween.tween_interval(2.5)
	notif_tween.tween_property(notification_label, "modulate:a", 0.0, 0.8)

func show_game_over(days_survived: int) -> void:
	game_over_panel.visible = true
	days_survived_label.text = "You survived for %d Day(s)" % days_survived

func _on_restart_pressed() -> void:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("restart_game"):
		main_scene.restart_game()
