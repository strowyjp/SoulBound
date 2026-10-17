extends Area2D

@onready var heal_audio = $HealAudio
@onready var upgrade_particles = $UpgradeParticles
@onready var healing_particles = $HealingParticles
@onready var button = $CanvasLayer/rest
@onready var upgrade = $CanvasLayer/UpgradeLevel
const UPGRADE_UI = preload("res://scenes/upgrade_player_level.tscn")

const COOLDOWN_HIGH_HP = 30.0
const COOLDOWN_MID_HP = 60.0
const COOLDOWN_LOW_HP = 120.0

var player_in_range = null
var can_heal = true

func _ready() -> void:
	upgrade_particles.process_material = upgrade_particles.process_material.duplicate()
	
	healing_particles.emitting = false
	upgrade_particles.emitting = false
	can_heal = true
	button.hide()
	upgrade.hide()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		upgrade.show()

func _get_cooldown_time(current_hp: float, max_hp: float) -> float:
	var hp_percent = (current_hp / max_hp) * 100.0
	if hp_percent >= 80.0:
		return COOLDOWN_HIGH_HP
	elif hp_percent >= 40.0:
		return COOLDOWN_MID_HP
	else:
		return COOLDOWN_LOW_HP

func _on_rest_pressed() -> void:
	if player_in_range and can_heal and player_in_range.current_health < player_in_range.max_health:
		if heal_audio:
			heal_audio.play()
		var wait_time = _get_cooldown_time(player_in_range.current_health, player_in_range.max_health)
		
		player_in_range.heal(player_in_range.max_health)
		button.hide()
		can_heal = false
		
		healing_particles.position = Vector2.ZERO
		healing_particles.restart()
		healing_particles.emitting = true
		
		var start_pos = healing_particles.global_position
		var target_pos = player_in_range.global_position
		
		var tween_x = create_tween()
		tween_x.tween_property(healing_particles, "global_position:x", target_pos.x, 0.5)
		
		var tween_y = create_tween()
		var jump_height = start_pos.y - 100 
		tween_y.tween_property(healing_particles, "global_position:y", jump_height, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_y.tween_property(healing_particles, "global_position:y", target_pos.y, 0.25).set_trans(Tween.TRANS_SINE)
		
		await tween_x.finished
		
		await get_tree().create_timer(wait_time).timeout
		can_heal = true

func _on_upgrade_lvl_pressed() -> void:
	if player_in_range:
		var ui = UPGRADE_UI.instantiate()
		ui.player = player_in_range
		ui.shrine = self
		
		ui.tree_exited.connect(_on_upgrade_ui_closed)
		
		get_tree().current_scene.add_child(ui)
		button.hide()
		upgrade.hide()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = null
		button.hide()
		upgrade.hide()

func play_upgrade_effect() -> void:
	if not player_in_range:
		return

	var player = player_in_range
	var mat = upgrade_particles.process_material as ParticleProcessMaterial

	upgrade_particles.global_position = player.global_position
	upgrade_particles.scale = Vector2(2.5, 2.5)

	if mat:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 45.0
		mat.initial_velocity_min = 0.0
		mat.initial_velocity_max = 0.0
		mat.radial_accel_min = -900.0
		mat.radial_accel_max = -900.0
		mat.color = Color("#B026FF")

	upgrade_particles.amount = 45
	upgrade_particles.lifetime = 0.7
	upgrade_particles.emitting = true

	await get_tree().create_timer(0.38).timeout

	upgrade_particles.emitting = false

	var original_scale = player.scale

	var pulse = player.create_tween()
	pulse.tween_property(
		player,
		"scale",
		original_scale * 1.15,
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	pulse.tween_property(
		player,
		"scale",
		original_scale,
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if mat:
		mat.radial_accel_min = 180.0
		mat.radial_accel_max = 300.0
		mat.initial_velocity_min = 50.0
		mat.initial_velocity_max = 100.0
		mat.color = Color("#FFD700")

	upgrade_particles.global_position = player.global_position
	upgrade_particles.restart()
	upgrade_particles.emitting = true

	await get_tree().create_timer(0.35).timeout

	upgrade_particles.emitting = false

func _process(_delta: float) -> void:
	if player_in_range and can_heal and player_in_range.current_health < player_in_range.max_health:
		button.show()
	else:
		button.hide()

func _on_upgrade_ui_closed() -> void:
	if player_in_range:
		upgrade.show()
