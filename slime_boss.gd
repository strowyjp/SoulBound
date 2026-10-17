extends CharacterBody2D

@onready var death_audio = $DeathAudio
@onready var boss_music = $BossMusic
var map_music_player: AudioStreamPlayer = null

signal health_changed(new_health)

@export var enemy_type: String = "boss_slime"
const HITODAMA_SCENE = preload("res://scenes/enemy_hitodama.tscn")
const PURPLE_HITODAMA = preload("res://scenes/purple_hitodama.tscn")
const SMALL_SLIME_SCENE = preload("res://scenes/ghost_slime.tscn")

@export var hurt_cooldown_time: float = 1.2
var hurt_cooldown_timer: float = 0.0

@export var speed = 75.0
@export var accel = 250.0
@export var friction = 300.0
@export var obstacle_avoid_distance = 65.0
@export var max_chase_distance = 700.0
@export var safe_distance = 35.0

@export var far_despawn_distance: float = 600.0
@export var far_despawn_time: float = 20.0
var far_timer: float = 0.0

@export var souls_reward = 50

@export var max_hp = 350
@export var current_hp = 350

@export var knockback_force = 50.0
@export var knockback_time = 0.22
@export var hit_stun_time = 0.04

@export var attack_damage = 19
@export var attack_distance = 80.0
@export var keep_distance = 45.0
@export var attack_cooldown = 0.5
@export var attack_hit_delay = 0.5
@export var attack_hit_time = 0.2

@export var soul_burst_cooldown: float = 12.0
@export var soul_sacrifice_hp: int = 25

enum State {
	IDLE,
	WANDER,
	ALERT,
	CHASE,
	ATTACK,
	INVESTIGATE,
}

var current_state = State.IDLE

var player: Node2D = null
var last_known_position = Vector2.ZERO
var investigate_timer = 0.0
var move_direction = Vector2.ZERO
var last_direction = Vector2(0, 1)
var state_timer = 0.0
var damage_number_scene = preload("res://scenes/damage_number.tscn")
var is_dead = false
var is_knocked_back = false
var is_hurt = false
var is_attacking = false
var attack_has_hit = false
var stuck_timer = 0.0
var knockback_timer = 0.0
var hit_stun_timer = 0.0
var attack_cooldown_timer = 0.0

var is_phase_two: bool = false
var has_spawned_minions: bool = false
var can_use_soul_burst: bool = true
var soul_burst_timer: float = 0.0

var damage_multiplier: float = 0.7

var num_rays = 8
var ray_directions = []
var interest = []
var danger = []

@onready var anim = $AnimatedSprite2D
@onready var hurtbox = $HurtBox
@onready var hitbox = $hitbox

func _ready():
	current_hp = max_hp

	hitbox.monitoring = false
	anim.animation_finished.connect(_on_animation_finished)

	for i in range(num_rays):
		var angle = i * 2 * PI / num_rays
		ray_directions.append(Vector2.RIGHT.rotated(angle))
		interest.append(0.0)
		danger.append(0.0)

	await get_tree().create_timer(0.1).timeout
	map_music_player = get_tree().current_scene.get_node_or_null("GraveyardAreaAudio")
	if map_music_player and map_music_player.playing:
		map_music_player.stop()

	if boss_music:
		boss_music.play()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player != null:
		var is_player_dead = not is_instance_valid(player) or ("is_dead" in player and player.is_dead) or ("current_hp" in player and player.current_hp <= 0)
		if is_player_dead:
			_despawn_boss()
			return

		var dist = global_position.distance_to(player.global_position)
		if dist > far_despawn_distance:
			far_timer += delta
			if far_timer >= far_despawn_time:
				_despawn_boss()
				return
		else:
			far_timer = 0.0

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if is_phase_two and not can_use_soul_burst:
		soul_burst_timer -= delta
		if soul_burst_timer <= 0:
			can_use_soul_burst = true

	if is_knocked_back:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 850.0 * delta)
		move_and_slide()
		if knockback_timer <= 0:
			is_knocked_back = false
			hit_stun_timer = hit_stun_time
		return

	if hit_stun_timer > 0:
		hit_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		return
	
	if is_attacking:
		var separation = _get_separation_direction()
		if separation != Vector2.ZERO:
			velocity = velocity.move_toward(separation * speed, accel * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			
		move_and_slide()
		return

	_update_state_machine(delta)
	_movement(delta)

	if not is_hurt:
		_update_animation()

func _despawn_boss():
	if boss_music and boss_music.playing:
		boss_music.stop()
	if is_instance_valid(map_music_player):
		map_music_player.play()
	queue_free()

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	query.exclude = [get_rid()]

	var result = space_state.intersect_ray(query)
	if result and result.collider != player:
		return false

	return true

func _update_state_machine(delta: float):
	state_timer -= delta

	if is_instance_valid(player):
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > max_chase_distance:
			current_state = State.IDLE
			move_direction = Vector2.ZERO
			return

	if current_state in [State.IDLE, State.WANDER] and is_instance_valid(player):
		if _has_line_of_sight():
			current_state = State.CHASE

	match current_state:
		State.IDLE:
			move_direction = Vector2.ZERO
			if state_timer <= 0:
				current_state = State.WANDER
				state_timer = randf_range(2.0, 4.0)

		State.WANDER:
			if state_timer <= 0:
				current_state = State.IDLE
				state_timer = randf_range(1.0, 3.0)
			elif move_direction == Vector2.ZERO:
				move_direction = Vector2(
					randf_range(-1.0, 1.0),
					randf_range(-1.0, 1.0)
				).normalized()

		State.ALERT:
			move_direction = Vector2.ZERO

		State.CHASE:
			if not is_instance_valid(player):
				current_state = State.IDLE
				return
			if not _has_line_of_sight():
				current_state = State.INVESTIGATE
				investigate_timer = 1.5
				return
			var distance = global_position.distance_to(player.global_position)
			last_direction = (player.global_position - global_position).normalized()

			if is_phase_two and can_use_soul_burst and distance <= attack_distance * 2.5:
				_cast_soul_burst()
				return

			if distance <= attack_distance:
				move_direction = Vector2.ZERO
				if attack_cooldown_timer <= 0:
					current_state = State.ATTACK
					_attack()
			elif distance < keep_distance:
				var retreat_direction = (
					global_position - player.global_position
				).normalized()
				move_direction = retreat_direction
				last_direction = retreat_direction
			else:
				last_known_position = player.global_position
				_set_interest(player.global_position)
				_set_danger()
				_choose_direction()

		State.ATTACK:
			move_direction = Vector2.ZERO

		State.INVESTIGATE:
			if is_instance_valid(player) and _has_line_of_sight():
				current_state = State.CHASE
				return

			investigate_timer -= delta
			_set_interest(last_known_position)
			_set_danger()
			_choose_direction()

			if investigate_timer <= 0 or global_position.distance_to(last_known_position) < 10:
				current_state = State.IDLE
				move_direction = Vector2.ZERO

func _cast_soul_burst():
	if is_dead or is_hurt or is_attacking:
		return

	is_attacking = true
	can_use_soul_burst = false
	soul_burst_timer = soul_burst_cooldown
	move_direction = Vector2.ZERO
	velocity = Vector2.ZERO

	if abs(last_direction.x) > abs(last_direction.y):
		anim.play("side_idle")
		anim.flip_h = last_direction.x < 0
	else:
		anim.flip_h = false
		if last_direction.y > 0:
			anim.play("front_idle")
		else:
			anim.play("back_idle")

	var original_modulate = anim.modulate
	await get_tree().create_timer(1.0).timeout
	anim.modulate = original_modulate

	if is_dead or not is_inside_tree():
		is_attacking = false
		return

	if not has_spawned_minions:
		has_spawned_minions = true
		_spawn_minions()

	current_hp = max(current_hp - soul_sacrifice_hp, 1)
	health_changed.emit(current_hp)
	_spawn_damage_number(soul_sacrifice_hp, false)

	for i in range(8):
		var angle = i * (PI / 4)
		var dir = Vector2(cos(angle), sin(angle)).normalized()
		var soul = PURPLE_HITODAMA.instantiate()
		soul.global_position = global_position
		if "direction" in soul:
			soul.direction = dir
		get_parent().add_child(soul)

	if current_hp <= 0:
		die()
		return

	is_attacking = false

func _spawn_minions():
	for i in range(4):
		var angle = i * (PI / 2)
		var offset = Vector2(cos(angle), sin(angle)) * 40.0
		var minion = SMALL_SLIME_SCENE.instantiate()
		minion.global_position = global_position + offset
		get_parent().add_child(minion)

func _attack():
	if is_attacking or is_dead or is_hurt:
		return

	is_attacking = true
	attack_has_hit = false
	attack_cooldown_timer = attack_cooldown
	move_direction = Vector2.ZERO

	if is_instance_valid(player):
		var attack_direction = (player.global_position - global_position).normalized()
		last_direction = attack_direction
		velocity = attack_direction * (speed * 1.6)

		if abs(attack_direction.x) > abs(attack_direction.y):
			anim.flip_h = attack_direction.x < 0
			anim.play("side_attack")
		else:
			anim.flip_h = false
			if attack_direction.y > 0:
				anim.play("front_attack")
			else:
				anim.play("back_attack")

	hitbox.monitoring = true

	await get_tree().create_timer(attack_hit_delay).timeout
	
	if is_dead or is_hurt or not is_inside_tree():
		hitbox.monitoring = false
		is_attacking = false
		return

	_deal_attack_damage()

	await get_tree().create_timer(attack_hit_time).timeout
	hitbox.monitoring = false

	if is_dead or is_hurt:
		is_attacking = false
		return

func _deal_attack_damage():
	if attack_has_hit or not is_instance_valid(player):
		return

	for area in hitbox.get_overlapping_areas():
		if area.is_in_group("player_hurtbox"):
			var target = area.get_parent()
			if target == player and target.has_method("take_damage"):
				target.take_damage(attack_damage, global_position)
				attack_has_hit = true
				return

func _set_interest(target_pos: Vector2):
	var path_direction = (target_pos - global_position).normalized()
	for i in range(num_rays):
		var d = ray_directions[i].dot(path_direction)
		interest[i] = max(0.0, d)

func _set_danger():
	var space_state = get_world_2d().direct_space_state
	var exclude_array: Array[RID] = [get_rid()]
	if is_instance_valid(player):
		exclude_array.append(player.get_rid())

	for i in range(num_rays):
		danger[i] = 0.0
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + ray_directions[i] * obstacle_avoid_distance
		)
		query.exclude = exclude_array
		var result = space_state.intersect_ray(query)
		if result and result.collider != player:
			danger[i] = 1.0

func _choose_direction():
	for i in range(num_rays):
		if danger[i] > 0.0:
			interest[i] = 0.0

	var chosen_dir = Vector2.ZERO
	for i in range(num_rays):
		chosen_dir += ray_directions[i] * interest[i]

	move_direction = chosen_dir.normalized()

func _movement(delta: float):
	var old_pos = global_position
	var current_speed = speed
	var separation = _get_separation_direction()
	var final_dir = move_direction

	if separation != Vector2.ZERO:
		final_dir = (final_dir + separation * 3.0).normalized()

	if final_dir != Vector2.ZERO:
		velocity = velocity.move_toward(final_dir * current_speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	if move_direction != Vector2.ZERO and global_position.distance_to(old_pos) < 0.5:
		stuck_timer += delta
		if stuck_timer > 0.3:
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0

func _update_animation():
	if is_attacking:
		return
		
	if move_direction != Vector2.ZERO:
		last_direction = move_direction

		if abs(move_direction.x) > abs(move_direction.y):
			anim.play("side_walk")
			anim.flip_h = move_direction.x < 0
		else:
			anim.flip_h = false
			if move_direction.y > 0:
				anim.play("front_walk")
			else:
				anim.play("back_walk")
	else:
		if abs(last_direction.x) > abs(last_direction.y):
			anim.play("side_idle")
			anim.flip_h = last_direction.x < 0
		else:
			anim.flip_h = false
			if last_direction.y > 0:
				anim.play("front_idle")
			else:
				anim.play("back_idle")

func take_damage(amount: int, is_crit: bool = false):
	if is_dead:
		return

	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	var actual_damage = int(amount * damage_multiplier)
	current_hp = max(current_hp - actual_damage, 0)
	health_changed.emit(current_hp)
	
	_spawn_damage_number(actual_damage, is_crit)

	if current_hp <= max_hp * 0.5 and not is_phase_two:
		is_phase_two = true
		move_direction = Vector2.ZERO
		velocity = Vector2.ZERO
		
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < 150.0:
			if player.has_method("take_damage"):
				var push_dir = (player.global_position - global_position).normalized()
				player.velocity = push_dir * 400.0

	if not is_attacking and hurt_cooldown_timer <= 0:
		hurt_cooldown_timer = hurt_cooldown_time
		hitbox.set_deferred("monitoring", false)
		
		if is_instance_valid(player):
			current_state = State.CHASE
			var knockback_direction = (global_position - player.global_position).normalized()
			velocity = knockback_direction * knockback_force
			is_knocked_back = true
			knockback_timer = knockback_time

		_play_hurt()

	if current_hp <= 0:
		die()

func _play_hurt():
	if is_dead:
		return

	is_hurt = true

	if abs(last_direction.x) > abs(last_direction.y):
		anim.flip_h = last_direction.x < 0
		anim.play("side_hurt")
	else:
		anim.flip_h = false
		if last_direction.y > 0:
			anim.play("front_hurt")
		else:
			anim.play("back_hurt")

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	is_knocked_back = false
	hit_stun_timer = 0.0
	is_attacking = false
	is_hurt = false
	
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_first_boss_killed = true
		SaveManager.save_game(player)

	if boss_music and boss_music.playing:
		boss_music.stop()

	if is_instance_valid(map_music_player):
		map_music_player.play()

	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitoring", false)

	var body_collision = get_node_or_null("CollisionShape2D")
	if body_collision:
		body_collision.set_deferred("disabled", true)

	if death_audio:
		death_audio.pitch_scale = randf_range(0.85, 1.1)
		death_audio.play()

	if abs(last_direction.x) > abs(last_direction.y):
		anim.flip_h = last_direction.x < 0
		anim.play("side_death")
	else:
		anim.flip_h = false
		if last_direction.y > 0:
			anim.play("front_death")
		else:
			anim.play("back_death")

	await anim.animation_finished
	var soul = HITODAMA_SCENE.instantiate()
	soul.global_position = global_position
	if "souls_amount" in soul:
		soul.souls_amount = souls_reward
	get_parent().add_child(soul)
	queue_free()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		if current_state == State.CHASE:
			current_state = State.INVESTIGATE
			investigate_timer = 1.5

func _get_separation_direction() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = safe_distance
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.exclude = [get_rid()]
	
	var results = space_state.intersect_shape(query)
	var sep_dir = Vector2.ZERO
	
	for res in results:
		var collider = res.collider
		if collider is CharacterBody2D:
			var diff = global_position - collider.global_position
			var dist = diff.length()
			if dist > 0 and dist < safe_distance:
				sep_dir += diff.normalized() * (safe_distance - dist)
				
	if sep_dir != Vector2.ZERO:
		return sep_dir.normalized()
	return Vector2.ZERO

func _spawn_damage_number(amount: int, is_crit: bool):
	if damage_number_scene:
		var damage_inst = damage_number_scene.instantiate()
		var offset_x = randf_range(-35.0, 35.0)
		var offset_y = randf_range(-30.0, 15.0)
		damage_inst.global_position = global_position + Vector2(offset_x, offset_y)
		get_tree().current_scene.add_child(damage_inst)
		damage_inst.setup(amount, is_crit)

func _on_animation_finished():
	if is_dead:
		return

	if is_hurt:
		is_hurt = false
		_reset_state_after_action()
		return

	if is_attacking:
		is_attacking = false
		_reset_state_after_action()
		return

func _reset_state_after_action():
	if is_instance_valid(player):
		current_state = State.CHASE
	else:
		current_state = State.IDLE

func force_return(center_pos: Vector2):
	is_attacking = false
	player = null
	current_state = State.WANDER
	move_direction = (center_pos - global_position).normalized()
	state_timer = 3.0

func enter_light_zone():
	damage_multiplier = 1.0
	
func exit_light_zone():
	damage_multiplier = 0.7
