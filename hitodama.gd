extends GPUParticles2D

@onready var light = $PointLight2D
var heal_timer = Timer
var time = 0.0
var is_friendly: bool = false
var is_following: bool = false
var player = null
var speed: float = 55.0
var wander_radius: float = 70.0
var target_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var base_position: Vector2
var right_limit: float = 840
var left_limit: float = -1040
var top_limit: float = -600
var bottom_limit: float = 125

func _ready():
	heal_timer = Timer.new()
	heal_timer.wait_time = 2
	heal_timer.one_shot = false
	heal_timer.timeout.connect(_on_heal_timer_timeout)
	add_child(heal_timer)
	base_position = global_position
	set_new_random_target()
	if randf() <= 0.02:
		is_friendly = true
		if light:
			light.texture_scale = 5.0

func _process(delta):
	time += delta
	var target = Vector2.ZERO
	if is_friendly and is_following and player:
		target = player.global_position
	else:
		target = target_position
	var direction = (target - base_position).normalized()
	var desired_velocity = direction * speed
	velocity = velocity.lerp(desired_velocity, 1.5 * delta)
	base_position += velocity * delta
	if base_position.x <= left_limit and not is_friendly or base_position.x >= right_limit and not is_friendly:
		base_position.x = clamp(base_position.x, left_limit, right_limit)
		target_position.x = base_position.x + (base_position.x - target_position.x) 
	if base_position.y <= top_limit and not is_friendly or base_position.y >= bottom_limit and not is_friendly:
		base_position.y = clamp(base_position.y, top_limit, bottom_limit)
		target_position.y = base_position.y + (base_position.y - target_position.y)
	var float_speed = 8.0 if is_friendly else 5.5
	var float_x = cos(time * float_speed) * 5.0
	var float_y = sin(time * 3.0) * 8.0
	global_position = base_position + Vector2(float_x, float_y)
	if light:
		if is_friendly:
			light.energy = 1.8 + sin(time * 8.0) * 0.4
		else:
			light.energy = 1.4 + sin(time * 5.0) * 0.2
	if not is_following and base_position.distance_to(target_position) < 10.0:
		set_new_random_target()

func set_new_random_target():
	var random_x = randf_range(-wander_radius, wander_radius)
	var random_y = randf_range(-wander_radius, wander_radius)
	target_position = base_position + Vector2(random_x, random_y)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		if is_friendly:
			heal_timer.start()
			is_following = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		await get_tree().create_timer(6.0).timeout
		heal_timer.stop()
		is_following = false
		player = null


func _on_heal_timer_timeout():
	if player:
		player.heal(1)



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("enter_light_zone"):
		body.enter_light_zone()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("exit_light_zone"):
		body.exit_light_zone()
