extends Area2D

@export var night_color: Color = Color(1.0, 0.684, 0.46, 1.0)
@export var damage_amount: int = 1
@export var damage_interval: float = 2.0

@onready var day_night_color: CanvasModulate = $"../world_color"

var tween: Tween
var player_ref: Node2D = null
var damage_timer: Timer

func _ready() -> void:
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_on_damage_timeout)
	add_child(damage_timer)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		
		var zones: int = day_night_color.get_meta("active_zones", 0)
		if zones == 0 and not day_night_color.has_meta("original_color"):
			day_night_color.set_meta("original_color", day_night_color.color)
			
		day_night_color.set_meta("active_zones", zones + 1)
		
		if tween: tween.kill()
		day_night_color.set_process(false)
		
		tween = create_tween()
		tween.tween_property(day_night_color, "color", night_color, 1.5)
		
		apply_damage()
		damage_timer.start()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = null
		damage_timer.stop()
		
		var zones: int = max(0, day_night_color.get_meta("active_zones", 0) - 1)
		day_night_color.set_meta("active_zones", zones)
		
		if tween: tween.kill()
		
		if zones == 0:
			var target_c = day_night_color.get_meta("original_color", day_night_color.color)
			if "target_color" in day_night_color:
				target_c = day_night_color.get("target_color")
				
			tween = create_tween()
			tween.tween_property(day_night_color, "color", target_c, 1.5)
			
			await tween.finished
			if day_night_color.get_meta("active_zones", 0) == 0:
				day_night_color.set_process(true)

func _on_damage_timeout() -> void:
	apply_damage()

func apply_damage() -> void:
	if player_ref and player_ref.has_method("take_damage"):
		player_ref.take_damage(damage_amount)
