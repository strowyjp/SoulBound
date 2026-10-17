extends CharacterBody2D

@export var enemy_type: String = "ghost_slime"
const HITODAMA_SCENE = preload("res://scenes/enemy_hitodama.tscn")
@export var speed = 100.0
@export var accel = 300.0
@export var friction = 300.0
@export var obstacle_avoid_distance = 30.0
@export var max_chase_distance = 600.0
@export var safe_distance = 15.0
@export var souls_reward = 7

@export var max_hp = 30
@export var current_hp = 30

@export var knockback_force = 100.0
@export var knockback_time = 0.22
@export var hit_stun_time = 0.12

@onready var death_audio = $DeathAudio

@export var attack_damage = 7
@export var attack_distance = 45.0
@export var keep_distance = 25.0
@export var attack_cooldown = 0.35
@export var attack_hit_delay = 0.2
@export var attack_hit_time = 0.2

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

var damage_multiplier: float = 0.3

var is_sacrificed: bool = false

var num_rays = 8
var ray_directions = []
var interest = []
var danger = []

@onready var anim = $AnimatedSprite2D
@onready var hurtbox = $HurtBox
@onready var hitbox = $hitbox

func _ready():
	current_hp = max_hp
	anim.self_modulate.a = 0.15

	hitbox.monitoring = false
	anim.animation_finished.connect(_on_animation_finished)

	for i in range(num_rays):
		var angle = i * 2 * PI / num_rays
		ray_directions.append(Vector2.RIGHT.rotated(angle))
		interest.append(0.0)
		danger.append(0.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

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
			player = null
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
		velocity = attack_direction * (speed * 1.8)

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
	_spawn_damage_number(actual_damage, is_crit)

	if not is_attacking and not is_knocked_back:
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
		return

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
		var offset_x = randf_range(-25.0, 25.0)
		var offset_y = randf_range(-20.0, 10.0)
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
	create_tween().tween_property(anim, "self_modulate:a", 0.7, 0.3)
	
func exit_light_zone():
	damage_multiplier = 0.3
	create_tween().tween_property(anim, "self_modulate:a", 0.25, 0.3)

func freeze_for_sacrifice(target_pos: Vector2) -> void:
	if is_sacrificed:
		return

	is_sacrificed = true
	is_attacking = false
	is_hurt = false
	is_knocked_back = false
	player = null
	current_state = State.IDLE
	move_direction = Vector2.ZERO
	velocity = Vector2.ZERO

	if hitbox:
		hitbox.set_deferred("monitoring", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)

	if anim:
		anim.stop()
		anim.play("front_idle")

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"global_position",
		target_pos,
		0.4
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if anim:
		tween.tween_property(
			anim,
			"self_modulate",
			Color(0.4, 0.7, 1.0, 1.0),
			0.4
		)
