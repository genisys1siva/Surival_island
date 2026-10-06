extends StaticBody2D
class_name Shelter

func interact_shelter(player: Player) -> void:
	# Heal player and trigger night skip if night time
	player.heal(50.0)
	player.hunger = min(player.max_hunger, player.hunger + 30.0)
	player.emit_signal("hunger_changed", player.hunger, player.max_hunger)
	player.emit_signal("notification_requested", "Rested in Shelter (+50 HP, +30 Hunger)")

	# Tell main script to advance day/night cycle
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("skip_to_dawn"):
		main_scene.skip_to_dawn()
