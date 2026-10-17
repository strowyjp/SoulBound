extends Node2D

@export_group("Enemy Types Config")
@export var enemy_dictionary: Dictionary[String, PackedScene] = {}

@export_group("Spawn Settings")
@export var selected_enemy_type: String = "slime"
@export var max_enemies: int = 5
@export var spawn_interval: float = 3.0

@onready var spawn_area: Area2D = $SpawnArea
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D
@onready var spawn_timer: Timer = $SpawnTimer

var current_enemies: Array[Node2D] = []

func _ready() -> void:
	spawn_area.set_meta("enemy_type", selected_enemy_type)
	spawn_area.monitoring = true
	spawn_area.monitorable = true
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	current_enemies = current_enemies.filter(func(e): return is_instance_valid(e))
	if current_enemies.size() >= max_enemies:
		return
	_spawn_enemy()

func _spawn_enemy() -> void:
	if not enemy_dictionary.has(selected_enemy_type) or not spawn_shape or not spawn_shape.shape:
		return
		
	var enemy_scene = enemy_dictionary[selected_enemy_type]
	if not enemy_scene:
		return
		
	var enemy = enemy_scene.instantiate()
	enemy.global_position = _get_random_point_in_area()
	
	if "enemy_type" in enemy:
		enemy.enemy_type = selected_enemy_type
	
	get_parent().add_child.call_deferred(enemy)
	current_enemies.append(enemy)

func _get_random_point_in_area() -> Vector2:
	var rect = spawn_shape.shape.get_rect()
	var random_x = randf_range(rect.position.x, rect.end.x)
	var random_y = randf_range(rect.position.y, rect.end.y)
	var local_pos = Vector2(random_x, random_y)
	return spawn_shape.to_global(local_pos)

func _on_spawn_area_body_exited(body: Node2D) -> void:
	if not is_instance_valid(body) or not body.has_method("force_return"):
		return
		
	var enemy_t = body.enemy_type if "enemy_type" in body else selected_enemy_type
	call_deferred("_check_enemy_returned", body, enemy_t)

func _check_enemy_returned(body: Node2D, enemy_t: String) -> void:
	if not is_instance_valid(body):
		return
	if not _is_position_in_valid_zone(body.global_position, enemy_t):
		body.force_return(spawn_area.global_position)

func _is_position_in_valid_zone(pos: Vector2, target_type: String) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	for res in results:
		var area = res.collider
		if area is Area2D and area.has_meta("enemy_type"):
			if area.get_meta("enemy_type") == target_type:
				return true
				
	return false
