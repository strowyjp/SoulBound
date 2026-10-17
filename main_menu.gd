extends CanvasLayer

@onready var audio = $Audio

@export var game_scene: PackedScene 

@onready var bg = $BackGround
@onready var moon = $BackGround/Moon
@onready var sun = $BackGround/Sun
@onready var stars = $BackGround/Stars
@onready var clouds = $BackGround/Clouds

@onready var main_panel = $Control
@onready var settings_panel = $Settings

@onready var music_slider = $Settings/VBoxContainer/Music/MusicSlider
@onready var sfx_slider = $Settings/VBoxContainer/SFX/SFXSlider

var night_color: Color = Color("0d1117")
var day_color: Color = Color("4a86e8")

@export var moon_speed: float = 0.15
@export var horizontal_speed: float = 75.0
@export var arc_height: float = 300.0 

var time_passed: float = 0.0
var is_day: bool = false
var start_y: float

var music_bus: int
var sfx_bus: int

func _ready():
	if audio:
		audio.play()
	main_panel.visible = true
	settings_panel.visible = false
	
	music_bus = AudioServer.get_bus_index("Music")
	sfx_bus = AudioServer.get_bus_index("SFX")
	
	if has_node("Settings/VBoxContainer/Music/MusicSlider") and music_bus != -1:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	if has_node("Settings/VBoxContainer/SFX/SFXSlider") and sfx_bus != -1:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	
	if moon:
		start_y = moon.position.y
	if clouds:
		clouds.modulate.a = 0.0
	if sun:
		sun.position.x = -150.0

func _process(delta):
	var screen_width = get_viewport().size.x
	var start_x = -150.0
	var end_x = screen_width + 100.0
	
	var active_node = sun if is_day else moon
	var inactive_node = moon if is_day else sun
	
	if active_node:
		active_node.position.x += horizontal_speed * delta
		
		var progress = remap(active_node.position.x, start_x, end_x, 0.0, PI)
		active_node.position.y = start_y - sin(progress) * arc_height
		
		if inactive_node:
			inactive_node.position.x = -220.0
		
		if active_node.position.x > end_x:
			is_day = !is_day
			active_node.position.x = start_x

	var target_color = day_color if is_day else night_color
	if bg and "color" in bg:
		bg.color = bg.color.lerp(target_color, delta * 0.8)

	if stars:
		stars.modulate.a = move_toward(stars.modulate.a, 0.0 if is_day else 1.0, delta * 0.8)
	if clouds:
		clouds.modulate.a = move_toward(clouds.modulate.a, 1.0 if is_day else 0.0, delta * 0.8)

func _on_new_game_pressed() -> void:
	get_tree().paused = false
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_start_button_pressed():
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)

func _on_settings_button_pressed():
	main_panel.visible = false
	settings_panel.visible = true

func _on_back_button_pressed():
	settings_panel.visible = false
	main_panel.visible = true

func _on_quit_button_pressed():
	get_tree().quit()

func _on_music_slider_value_changed(value: float):
	if value <= 0:
		AudioServer.set_bus_mute(music_bus, true)
	else:
		AudioServer.set_bus_mute(music_bus, false)
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float):
	if value <= 0:
		AudioServer.set_bus_mute(sfx_bus, true)
	else:
		AudioServer.set_bus_mute(sfx_bus, false)
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))
