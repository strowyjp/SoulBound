extends Node2D

@export var boss_scene: PackedScene
@export var boss_cost: int = 250
@export var require_first_boss_dead: bool = true

@onready var interact_button: Button = $CanvasLayer/InterectButton
@onready var player_area: Area2D = $PlayerArea 
@onready var player = get_tree().get_first_node_in_group("player")

var is_player_near: bool = false
var is_boss_spawned: bool = false
var can_spawn_boss: bool = true

func _ready() -> void:
	interact_button.hide()

func check_can_spawn() -> bool:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var first_boss_cleared = true
	if require_first_boss_dead:
		first_boss_cleared = player.is_first_boss_killed

	return can_spawn_boss and not is_boss_spawned and player.souls_count >= boss_cost and first_boss_cleared

func _on_interect_button_pressed() -> void:
	if check_can_spawn():
		player.decrease_souls(boss_cost)
		spawn_boss()

func spawn_boss() -> void:
	is_boss_spawned = true
	can_spawn_boss = false
	interact_button.hide()
	
	var boss = boss_scene.instantiate()
	boss.global_position = global_position
	boss.scale = Vector2.ZERO 
	get_parent().add_child(boss)
	
	boss.tree_exited.connect(_on_boss_died)
	
	var health_bar = get_tree().current_scene.find_child("FinalBossHealthBar", true, false)
	if health_bar:
		health_bar.setup_boss(boss)

	var tween = create_tween()
	tween.tween_property(boss, "scale", Vector2(2.5, 2.5), 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_boss_died() -> void:
	is_boss_spawned = false
	
	var health_bar = get_tree().current_scene.find_child("FinalBossHealthBar", true, false)
	if health_bar:
		health_bar.hide()
		
	await get_tree().create_timer(300.0).timeout
	can_spawn_boss = true
	
	if is_player_near and check_can_spawn():
		interact_button.show()

func _on_player_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		is_player_near = true
		if check_can_spawn():
			interact_button.show()

func _on_player_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_near = false
		interact_button.hide()
