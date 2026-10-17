extends CharacterBody2D

var is_dead: bool = false

@onready var hurt_audio = $HurtAudio
@onready var death_audio = $DeathAudio
@onready var attack_audio = $AttackAudio
@onready var day_night_color: CanvasModulate = get_tree().current_scene.get_node_or_null("world_color")
@onready var fog: ColorRect = get_tree().current_scene.get_node_or_null("fog")
var spawn_position: Vector2

signal souls_changed(new_amount)
signal health_changed(new_health, max_health)

@onready var attack_area = $hitbox
@onready var anim = $AnimatedSprite2D

var power_damage_growth = [5, 5, 4, 4, 4, 3, 3, 3, 3, 3]
var power_crit_rate_growth = [0.05, 0.04, 0.04, 0.03, 0.03, 0.02, 0.02, 0.02, 0.01, 0.01]
var power_crit_damage_growth = [0.15, 0.12, 0.1, 0.08, 0.08, 0.05, 0.05, 0.05, 0.04, 0.04]

var jutsu_speed_growth = [6, 6, 5, 5, 4, 4, 3, 3, 3, 3]
var jutsu_hp_growth = [40, 35, 30, 25, 20, 20, 15, 15, 10, 10]
var jutsu_cooldown_growth = [0.15, 0.12, 0.1, 0.1, 0.08, 0.08, 0.05, 0.05, 0.05, 0.04]

var power_level: int = 0
var jutsu_level: int = 0
var level: int:
	get:
		return power_level + jutsu_level

var max_level: int = 10
var soul_costs = [10, 20, 35, 60, 100, 160, 250, 380, 550, 800]

@export var crit_rate = 0.11
@export var crit_damage = [1.3, 1.5]
@export var damage = 12
@export var speed = 100
@export var attack_colddown = 1.5

var is_knocked_back = false
var knockback_timer = 0.0
@export var knockback_force = 200.0
@export var knockback_time = 0.15
@export var knockback_friction = 1200.0

var current_dir = "down"
var is_first_boss_killed: bool = false

var left_limit = -1840
var right_limit = 3440
var bottom_limit = 3568
var top_limit = -720

var souls_count: int = 0
var max_health: int = 100
var current_health: int = 100

var can_attack = true
var is_attacking = false

const death_menu = preload("res://scenes/death_menu.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	spawn_position = global_position
	
	SaveManager.load_game(self)
	
	anim.play("front_idle")

	if $Camera2D:
		$Camera2D.limit_left = left_limit
		$Camera2D.limit_right = right_limit
		$Camera2D.limit_bottom = bottom_limit
		$Camera2D.limit_top = top_limit

	health_changed.emit(current_health, max_health)

	if attack_area:
		attack_area.monitoring = false

func _physics_process(delta):
	if is_dead:
		return

	if is_knocked_back:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		move_and_slide()
		if knockback_timer <= 0:
			is_knocked_back = false
		return

	player_movement(delta)
	
	if Input.is_action_just_pressed("attack") and can_attack and not is_attacking:
		perform_attack()

func player_movement(_delta):
	velocity = Vector2.ZERO

	if is_attacking:
		return

	if Input.is_action_pressed("right"):
		current_dir = "right"
		play_anim(1)
		attack_area.rotation_degrees = 90
		velocity.x = speed
	elif Input.is_action_pressed("left"):
		current_dir = "left"
		play_anim(1)
		attack_area.rotation_degrees = 270
		velocity.x = -speed
	elif Input.is_action_pressed("down"):
		current_dir = "down"
		play_anim(1)
		attack_area.rotation_degrees = 180
		velocity.y = speed
	elif Input.is_action_pressed("up"):
		current_dir = "up"
		play_anim(1)
		attack_area.rotation_degrees = 0
		velocity.y = -speed
	else:
		play_anim(0)

	move_and_slide()

func perform_attack():
	can_attack = false
	is_attacking = true
	velocity = Vector2.ZERO
	
	if attack_audio:
		attack_audio.pitch_scale = randf_range(0.8, 1.3)
		attack_audio.play()

	if current_dir == "right":
		anim.flip_h = false
		anim.play("side_attack")
		attack_area.rotation_degrees = 90
	elif current_dir == "left":
		anim.flip_h = true
		anim.play("side_attack")
		attack_area.rotation_degrees = 270
	elif current_dir == "up":
		anim.flip_h = false
		anim.play("back_attack")
		attack_area.rotation_degrees = 0
	else:
		anim.flip_h = false
		anim.play("front_attack")
		attack_area.rotation_degrees = 180

	var final_damage = float(damage)
	var is_crit = false

	if randf() <= crit_rate:
		var random_multiplier = randf_range(crit_damage[0], crit_damage[1])
		final_damage = damage * random_multiplier
		is_crit = true

	attack_area.monitoring = true

	await get_tree().physics_frame
	
	if not is_attacking or is_dead:
		attack_area.monitoring = false
		return

	var hit_enemies = []

	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				if enemy not in hit_enemies:
					hit_enemies.append(enemy)
					enemy.take_damage(int(final_damage), is_crit)

	await get_tree().create_timer(0.3).timeout
	
	attack_area.monitoring = false
	is_attacking = false

	await get_tree().create_timer(attack_colddown).timeout
	can_attack = true

func play_anim(movement):
	if is_attacking:
		return

	if current_dir == "right":
		anim.flip_h = false
		anim.play("side_walk" if movement == 1 else "side_idle")
	elif current_dir == "left":
		anim.flip_h = true
		anim.play("side_walk" if movement == 1 else "side_idle")
	elif current_dir == "down":
		anim.flip_h = false
		anim.play("front_walk" if movement == 1 else "front_idle")
	elif current_dir == "up":
		anim.flip_h = false
		anim.play("back_walk" if movement == 1 else "back_idle")

func heal(amount: int):
	if current_health < max_health:
		current_health = min(current_health + amount, max_health)
		health_changed.emit(current_health, max_health)
		SaveManager.save_game(self)

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO):
	if is_dead:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	SaveManager.save_game(self)
	
	if hurt_audio:
		hurt_audio.pitch_scale = randf_range(0.95, 1.15)
		hurt_audio.play()

	if current_health <= 0:
		die()
		return

	if source_pos != Vector2.ZERO:
		var knockback_direction = (global_position - source_pos).normalized()
		velocity = knockback_direction * knockback_force
		is_knocked_back = true
		knockback_timer = knockback_time
		
		is_attacking = false
		can_attack = true
		if attack_area:
			attack_area.set_deferred("monitoring", false)

	anim.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color.WHITE, 0.2)

func add_souls(amount: int):
	souls_count += amount
	souls_changed.emit(souls_count)
	SaveManager.save_game(self)

func upgrade_power() -> bool:
	if power_level >= max_level:
		return false

	var index = power_level
	var cost = soul_costs[power_level]

	if souls_count < cost:
		return false

	souls_count -= cost
	souls_changed.emit(souls_count)

	damage += power_damage_growth[index]
	crit_rate += power_crit_rate_growth[index]

	var cd_growth = power_crit_damage_growth[index]
	crit_damage[0] += cd_growth
	crit_damage[1] += cd_growth

	power_level += 1
	SaveManager.save_game(self)

	return true

func upgrade_jutsu() -> bool:
	if jutsu_level >= max_level:
		return false

	var index = jutsu_level
	var cost = soul_costs[jutsu_level]

	if souls_count < cost:
		return false

	souls_count -= cost
	souls_changed.emit(souls_count)

	speed += jutsu_speed_growth[index]
	max_health += jutsu_hp_growth[index]
	current_health += jutsu_hp_growth[index]
	attack_colddown = max(0.1, attack_colddown - jutsu_cooldown_growth[index])

	jutsu_level += 1
	health_changed.emit(current_health, max_health)
	SaveManager.save_game(self)

	return true

func decrease_souls(amount: int):
	souls_count = max(0, souls_count - amount)
	souls_changed.emit(souls_count)
	SaveManager.save_game(self)

func die():
	if is_dead:
		return
	is_dead = true
	
	var loss_percentage: float = 0.10
	var souls_lost: int = int(souls_count * loss_percentage)
	souls_count = max(0, souls_count - souls_lost)
	souls_changed.emit(souls_count)
	SaveManager.save_game(self)

	if death_audio:
		death_audio.play()

	can_attack = false
	is_attacking = false
	set_physics_process(false)
	if attack_area:
		attack_area.set_deferred("monitoring", false)

	if anim.sprite_frames.has_animation("death"):
		anim.play("death")

	await get_tree().create_timer(1.0).timeout

	get_tree().paused = true

	var death_screen = death_menu.instantiate()
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(death_screen)

func respawn():
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)
	global_position = spawn_position
	can_attack = true
	is_attacking = false
	anim.modulate = Color.WHITE
	anim.play("front_idle")
	set_physics_process(true)

func move_camera_to_graveyard(graveyard_pos: Vector2, target_zoom: Vector2 = Vector2(1.2, 1.2)):
	var music_manager = get_tree().get_first_node_in_group("MusicManager")
	if music_manager:
		if music_manager.has_method("stop_music"):
			music_manager.stop_music()
		if music_manager.has_method("play_victory_music"):
			music_manager.play_victory_music()

	can_attack = false
	is_attacking = false
	set_physics_process(false)
	anim.play("front_idle")

	var camera = $Camera2D
	if camera:
		camera.top_level = true

	var tween1 = create_tween().set_parallel(true)
	if camera:
		tween1.tween_property(camera, "global_position", graveyard_pos, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween1.tween_property(camera, "zoom", target_zoom, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if day_night_color:
		tween1.tween_property(day_night_color, "color", Color("1a2236ff"), 2.5)

	if fog:
		tween1.tween_property(fog, "modulate:a", 1.0, 2.5)

	await tween1.finished

	var hitodamas_container = get_tree().current_scene.get_node_or_null("Hitodamas")
	if hitodamas_container and hitodamas_container.get_child_count() > 0:
		var tween_h = create_tween().set_parallel(true)
		
		for h in hitodamas_container.get_children():
			h.set_process(false)
			h.set_physics_process(false)
			
			tween_h.tween_property(h, "global_position:y", h.global_position.y - 160.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween_h.tween_property(h, "scale", h.scale * 2.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween_h.tween_property(h, "modulate:a", 0.0, 2.5)
			
			for child in h.get_children():
				if child is PointLight2D or child is Light2D:
					tween_h.tween_property(child, "energy", 0.0, 2.5)
				elif child is GPUParticles2D or child is CPUParticles2D:
					child.emitting = false

		await tween_h.finished
		
		for h in hitodamas_container.get_children():
			h.queue_free()

	if fog:
		var tween_fog = create_tween()
		tween_fog.tween_property(fog, "modulate:a", 0.0, 1.5)
		await tween_fog.finished

	if day_night_color:
		var tween_day = create_tween()
		tween_day.tween_property(day_night_color, "color", Color(1.15, 1.1, 1.0), 2.0)
		await tween_day.finished 
		
	SaveManager.delete_save()
	
	var victory_scene = preload("res://scenes/victory_menu.tscn").instantiate()
	get_tree().current_scene.add_child(victory_scene)
	
	if victory_scene.has_method("setup_stats"):
		victory_scene.setup_stats(souls_count, power_level, jutsu_level)
		
	get_tree().paused = true
