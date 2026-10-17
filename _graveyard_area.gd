extends Area2D

@onready var fog: ColorRect = get_tree().current_scene.get_node_or_null("fog")
@onready var day_night_color: CanvasModulate = $"../world_color"

var night_color: Color = Color("1b2337ff")
var tween: Tween

func _ready() -> void:
	if fog:
		fog.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var zones: int = day_night_color.get_meta("active_zones", 0)
		
		if zones == 0 and not day_night_color.has_meta("original_color"):
			day_night_color.set_meta("original_color", day_night_color.color)
			
		day_night_color.set_meta("active_zones", zones + 1)
		
		if tween: tween.kill()
		day_night_color.set_process(false)
		
		tween = create_tween().set_parallel(true)
		tween.tween_property(day_night_color, "color", night_color, 1.5)
		if fog:
			tween.tween_property(fog, "modulate:a", 1.0, 1.5)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		var zones: int = max(0, day_night_color.get_meta("active_zones", 0) - 1)
		day_night_color.set_meta("active_zones", zones)
		
		if tween: tween.kill()
		tween = create_tween().set_parallel(true)
		
		if fog:
			tween.tween_property(fog, "modulate:a", 0.0, 0.2)
		
		if zones == 0:
			var target_c = day_night_color.get_meta("original_color", day_night_color.color)
			if "target_color" in day_night_color:
				target_c = day_night_color.get("target_color")
				
			tween.tween_property(day_night_color, "color", target_c, 1.5)
			
			await tween.finished
			if day_night_color.get_meta("active_zones", 0) == 0:
				day_night_color.set_process(true)
