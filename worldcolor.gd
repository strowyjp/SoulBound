extends CanvasModulate

@export var day_duration: float = 10.0
@export var time_gradient: Gradient

var time_passed: float = 0.0
var in_custom_zone: bool = false
var color_tween: Tween

func _process(delta: float) -> void:
	time_passed += delta
	if not in_custom_zone:
		var time_percent = fmod(time_passed / day_duration, 1.0)
		color = time_gradient.sample(time_percent) if time_gradient else Color.WHITE

func override_color(target_color: Color, transition_time: float) -> void:
	in_custom_zone = true
	_create_tween_to(target_color, transition_time)
func restore_natural_time(transition_time: float) -> void:
	var time_percent = fmod(time_passed / day_duration, 1.0)
	var target_color = time_gradient.sample(time_percent) if time_gradient else Color.WHITE
	_create_tween_to(target_color, transition_time)
	color_tween.finished.connect(func(): in_custom_zone = false)

func _create_tween_to(target_color: Color, duration: float) -> void:
	if color_tween and color_tween.is_running():
		color_tween.kill()
	
	color_tween = create_tween()
	color_tween.tween_property(self, "color", target_color, duration)
