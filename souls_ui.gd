extends CanvasLayer

@onready var count_label = $Label
@onready var floating_label = $FloatingLabel
@onready var particles = $GPUParticles2D

var displayed_souls: int = 0
var target_souls: int = 0
var tween: Tween

func _ready():
	floating_label.hide()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("souls_changed"):
			player.souls_changed.connect(_on_souls_changed)

		displayed_souls = player.souls_count
		target_souls = player.souls_count
		count_label.text = format_souls(displayed_souls)

func _on_souls_changed(new_amount):
	var added_amount = new_amount - target_souls
	target_souls = new_amount

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_method(set_display_number, displayed_souls, target_souls, 0.2)

	if added_amount > 0:
		show_floating_text("+" + str(added_amount))
		particles.restart()

func set_display_number(value: float):
	displayed_souls = int(value)
	count_label.text = format_souls(displayed_souls)

func format_souls(amount: int) -> String:
	if amount >= 1_000_000:
		return str(snapped(amount / 1000000.0, 0.1)) + "M"
	elif amount >= 1_000:
		return str(snapped(amount / 1000.0, 0.1)) + "K"
	return str(amount)

func show_floating_text(text_string: String):
	floating_label.text = text_string
	floating_label.show()
	floating_label.modulate.a = 1.0
	floating_label.position = count_label.position + Vector2(0, -10)

	var float_tween = create_tween().set_parallel(true)

	float_tween.tween_property(
		floating_label,
		"position:y",
		floating_label.position.y - 35,
		0.6
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	float_tween.tween_property(
		floating_label,
		"modulate:a",
		0.0,
		0.6
	)

	float_tween.chain().tween_callback(floating_label.hide)
