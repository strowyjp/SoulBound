extends CanvasLayer

@onready var main_bar = $TextureProgressBar
@onready var damage_bar = $DamageProgressBar
@onready var particles = $TextureProgressBar/GPUParticles2D
@onready var soul_node = $TextureProgressBar/Hitodama
var soul_tween: Tween
var health_tween: Tween
var damage_tween: Tween

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
	particles.emitting = false

func _on_player_health_changed(new_health: int, max_health: int):
	check_soul_danger(new_health, max_health)
	if not main_bar or not damage_bar:
		return
	main_bar.max_value = max_health
	damage_bar.max_value = max_health
	var old_health = main_bar.value
	if new_health < old_health:
		shake_bar()
		main_bar.value = new_health
		if damage_tween:
			damage_tween.kill()
		damage_tween = create_tween()
		damage_tween.tween_interval(0.3)
		damage_tween.tween_property(damage_bar, "value", float(new_health), 0.4).set_trans(Tween.TRANS_SINE)
	elif new_health > old_health:
		if particles:
			particles.restart()
		damage_bar.value = new_health
		if health_tween:
			health_tween.kill()
		health_tween = create_tween()
		health_tween.tween_property(main_bar, "value", float(new_health), 0.4).set_trans(Tween.TRANS_SINE)

func _on_heal_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.heal(15)

func _on_damage_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.take_damage(20)


func check_soul_danger(current_health: int, max_health: int):
	if not soul_node:
		return
	var health_percentage = float(current_health) / float(max_health)
	if current_health <= 0:
		if soul_tween:
			soul_tween.kill()
			soul_tween = null
		soul_node.modulate = Color(0, 0, 0)
	elif health_percentage <= 0.3:
		if soul_tween and soul_tween.is_running():
			return
		soul_tween = create_tween().set_loops()
		soul_tween.tween_property(soul_node, "modulate", Color(0.2, 0.2, 0.2), 0.5)
		soul_tween.tween_property(soul_node, "modulate", Color.WHITE, 0.5)
	else:
		if soul_tween:
			soul_tween.kill()
			soul_tween = null
		soul_node.modulate = Color.WHITE

func shake_bar():
	var original_offset = offset
	var shake_tween = create_tween()
	for i in range(4):
		var random_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		shake_tween.tween_property(self, "offset", original_offset + random_offset, 0.02)
	shake_tween.tween_property(self, "offset", original_offset, 0.02)
