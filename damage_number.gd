extends Node2D

@onready var label = $Label

func setup(damage_amount: int, is_crit: bool = false):
	label.text = str(damage_amount)
	
	var random_x = randf_range(-15.0, 15.0)
	var target_position = position + Vector2(random_x, -35.0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if is_crit:
		label.modulate = Color(1.0, 0.3, 0.2)
		label.add_theme_font_size_override("font_size", 22)
		scale = Vector2(0.6, 0.6)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
		tween.chain().tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
		label.add_theme_font_size_override("font_size", 16)
		scale = Vector2(0.5, 0.5)
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
		tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	
	await tween.finished
	queue_free()
