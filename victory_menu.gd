extends CanvasLayer

@onready var stats_label = $Control/VBoxContainer/StatsLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_stats(souls: int, power_lvl: int, jutsu_lvl: int):
	stats_label.text = "Souls: %d\nPower level: %d | Jutsu level: %d" % [souls, power_lvl, jutsu_lvl]

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
