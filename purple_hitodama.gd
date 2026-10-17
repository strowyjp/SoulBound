extends GPUParticles2D

@export var speed: float = 180.0
@export var damage: int = 40
@export var life_time: float = 4.0

var direction: Vector2 = Vector2.ZERO

@onready var hitbox: Area2D = $HitBox

func _ready() -> void:
	emitting = true
	
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	get_tree().create_timer(life_time).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		global_position += direction * speed * delta
		rotation = direction.angle()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		_apply_damage(area.get_parent())

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_apply_damage(body)
	elif not body.is_in_group("enemy") and not body.is_in_group("boss"):
		queue_free()

func _apply_damage(target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(damage, global_position)
	queue_free()
