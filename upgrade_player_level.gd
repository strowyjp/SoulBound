extends CanvasLayer

var player: Node2D = null
var shrine: Node2D = null

@onready var upgrade_audio = $UpgradeAudio

@onready var info_panel = $NinePatchRect
@onready var power_panel = $power
@onready var jutsu_panel = $Jutsu

@onready var player_level_label = $NinePatchRect/level
@onready var main_info_label = $NinePatchRect/information

@onready var power_level_label = $power/level
@onready var power_info_label = $power/information
@onready var power_upgrade_button = $power/upgrade

@onready var jutsu_level_label = $Jutsu/level
@onready var jutsu_info_label = $Jutsu/information
@onready var jutsu_upgrade_button = $Jutsu/JutsuUpgrade


func _ready() -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if upgrade_audio:
		upgrade_audio.process_mode = Node.PROCESS_MODE_ALWAYS

	show_main_menu()
	update_ui()


func show_main_menu() -> void:
	info_panel.show()
	power_panel.hide()
	jutsu_panel.hide()


func update_ui() -> void:
	if not player:
		return

	player_level_label.text = str(player.level)

	power_level_label.text = str(player.power_level)
	jutsu_level_label.text = str(player.jutsu_level)

	var remaining = 10 - (player.power_level + player.jutsu_level)
	if remaining > 1:
		main_info_label.text = "%d upgrades\nremain. Forge\nyour path." % remaining
	elif remaining == 1:
		main_info_label.text = "1 upgrade\nremains. Forge\nyour path."
	else:
		main_info_label.text = "No upgrades\nremain. Path\nis forged."

	update_power_info()
	update_jutsu_info()


func update_power_info() -> void:
	if player.power_level >= player.max_level:
		power_info_label.text = "MAX LEVEL"
		power_upgrade_button.disabled = true
		return

	var index = player.power_level
	
	var cur_dmg = player.damage
	var next_dmg = cur_dmg + player.power_damage_growth[index]
	
	var cur_crit_r = player.crit_rate
	var next_crit_r = cur_crit_r + player.power_crit_rate_growth[index]
	
	var cur_crit_d = player.crit_damage[1]
	var next_crit_d = cur_crit_d + player.power_crit_damage_growth[index]
	
	var cost = player.soul_costs[player.power_level]
	
	power_info_label.text = "Power (Lv %d -> %d)\nDMG: %d -> %d\nCrit Rate: %.1f%% -> %.1f%%\nCrit DMG: %.1f -> %.1f\nCost: %d Souls" % [
		player.power_level, player.power_level + 1,
		cur_dmg, next_dmg,
		cur_crit_r * 100, next_crit_r * 100,
		cur_crit_d, next_crit_d,
		cost
	]
	
	power_upgrade_button.disabled = player.souls_count < cost


func update_jutsu_info() -> void:
	if player.jutsu_level >= player.max_level:
		jutsu_info_label.text = "MAX LEVEL"
		jutsu_upgrade_button.disabled = true
		return

	var index = player.jutsu_level

	var next_speed = player.speed + player.jutsu_speed_growth[index]
	var next_hp = player.max_health + player.jutsu_hp_growth[index]
	var next_cooldown = max(0.1, player.attack_colddown - player.jutsu_cooldown_growth[index])

	var cost = player.soul_costs[player.jutsu_level]

	jutsu_info_label.text = "HP: %d → %d\nSpeed: %d → %d\nCooldown: %.2f → %.2f\n\nCost: %d Souls" % [
		player.max_health, next_hp,
		player.speed, next_speed,
		player.attack_colddown, next_cooldown,
		cost
	]

	jutsu_upgrade_button.disabled = player.souls_count < cost


func _on_power_pressed() -> void:
	info_panel.hide()
	power_panel.show()
	update_power_info()


func _on_jutsu_pressed() -> void:
	info_panel.hide()
	jutsu_panel.show()
	update_jutsu_info()


func _on_upgrade_pressed() -> void:
	if player and player.has_method("upgrade_power"):
		if player.upgrade_power():
			hide()
			get_tree().paused = false

			if shrine and shrine.has_method("play_upgrade_effect"):
				shrine.play_upgrade_effect()

			if upgrade_audio:
				upgrade_audio.pitch_scale = randf_range(0.95, 1.15)
				upgrade_audio.play()
				await upgrade_audio.finished

			queue_free()


func _on_jutsu_upgrade_pressed() -> void:
	if player and player.has_method("upgrade_jutsu"):
		if player.upgrade_jutsu():
			hide()
			get_tree().paused = false

			if shrine and shrine.has_method("play_upgrade_effect"):
				shrine.play_upgrade_effect()

			if upgrade_audio:
				upgrade_audio.pitch_scale = randf_range(0.95, 1.15)
				upgrade_audio.play()
				await upgrade_audio.finished

			queue_free()


func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
