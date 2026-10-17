extends GPUParticles2D

var souls_amount: int = 1
var player = null
var current_speed: float = 0.0
var max_speed: float = 100.0
var is_homing: bool = false
var burst_velocity: Vector2 = Vector2.ZERO

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	var random_angle = randf_range(0, TAU)
	var random_speed = randf_range(100, 180)
	burst_velocity = Vector2.RIGHT.rotated(random_angle) * random_speed
	
	var tween = create_tween()
	tween.tween_property(self, "burst_velocity", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_homing = true)

func _process(delta):
	if not is_homing:
		global_position += burst_velocity * delta
		return
	if player:
		var distance = global_position.distance_to(player.global_position)
		var direction = global_position.direction_to(player.global_position)
		
		current_speed = move_toward(current_speed, max_speed, 800.0 * delta)
		global_position += direction * current_speed * delta
		
		if distance < 15.0:
			if player.has_method("add_souls"):
				player.add_souls(souls_amount)
			queue_free()
