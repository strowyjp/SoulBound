extends CanvasLayer

@onready var revive_audio = $ReviveAudio

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if revive_audio:
		revive_audio.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _on_restart_pressed():
	if revive_audio and revive_audio.stream != null:
		revive_audio.play()
		await revive_audio.finished
	else:
		await get_tree().create_timer(0.4, true, false, true).timeout
	
	get_tree().paused = false
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("respawn"):
		player.respawn()
		
	queue_free()
