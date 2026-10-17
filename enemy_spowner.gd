extends Area2D

@export var enemy_scene: PackedScene
@export var spawn_count: int = 5
@export var spawn_interval: float = 1.0
@export var spawn_margin: float = 100.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var enemies: Array[Node2D] = []


func _ready() -> void:
	body_exited.connect(_on_body_exited)
	await get_tree().process_frame
	spawn_enemies()
						


func spawn_enemies() -> void:
	for i in range(spawn_count):
		spawn_enemy()

		if i < spawn_count - 1:
			await get_tree().create_timer(spawn_interval).timeout


func spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)

	enemy.global_position = get_random_position_inside()
	enemies.append(enemy)

	if enemy.has_method("set_spawn_area"):
		enemy.set_spawn_area(self)

	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))


func get_random_position_inside() -> Vector2:
	var rect := collision_shape.shape as RectangleShape2D

	if rect == null:
		return global_position

	var half_size := rect.size / 2.0

	var local_position := Vector2(
		randf_range(
			-half_size.x + spawn_margin,
			half_size.x - spawn_margin
		),
		randf_range(
			-half_size.y + spawn_margin,
			half_size.y - spawn_margin
		)
	)

	return collision_shape.to_global(local_position)

func get_boundary_direction(enemy_position: Vector2) -> Vector2:
	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		return Vector2.ZERO
	var local_pos := to_local(enemy_position)
	var half_size := rect.size / 2.0
	var safe_margin = min(spawn_margin, min(half_size.x, half_size.y) - 5.0)
	if safe_margin < 0: 
		safe_margin = 0
		
	var direction := Vector2.ZERO
	
	if local_pos.x < -half_size.x + safe_margin:
		direction.x += 1.0
	elif local_pos.x > half_size.x - safe_margin:
		direction.x -= 1.0
	
	if local_pos.y < -half_size.y + safe_margin:
		direction.y += 1.0
	elif local_pos.y > half_size.y - safe_margin:
		direction.y -= 1.0
	
	return direction.normalized()


func _on_enemy_removed(enemy: Node2D) -> void:
	enemies.erase(enemy)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Enemies"):
		if body.has_method("force_return"):
			body.force_return(global_position)
