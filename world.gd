extends Node2D

@onready var world_music: AudioStreamPlayer = $WorldMusic
@onready var forest_audio: AudioStreamPlayer = $ForestAreaAudio
@onready var volcano_audio: AudioStreamPlayer = $VolcanoAreaAudio
@onready var graveyard_audio: AudioStreamPlayer = $GraveyardAreaAudio
@onready var victory_audio: AudioStreamPlayer = $VictoryMusic

var current_music: AudioStreamPlayer = null

func _ready() -> void:
	change_music(world_music)

func change_music(new_music: AudioStreamPlayer) -> void:
	if current_music == new_music and current_music != null and current_music.playing:
		return
	
	if current_music and current_music.playing:
		current_music.stop()
	
	current_music = new_music
	if current_music:
		current_music.play()

func _on_forest_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(forest_audio)

func _on_forest_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(world_music)

func _on_volcano_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(volcano_audio)

func _on_volcano_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(world_music)

func _on_graveyard_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(graveyard_audio)

func _on_graveyard_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		change_music(world_music)

func stop_music() -> void:
	if current_music and current_music.playing:
		current_music.stop()
	current_music = null

func play_victory_music() -> void:
	change_music(victory_audio)
