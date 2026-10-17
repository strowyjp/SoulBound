extends CanvasLayer

@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var damage_bar: TextureProgressBar = $DamageProgressBar

var tween: Tween

func _ready() -> void:
	hide()

func setup_boss(boss) -> void:
	show()
	setup_health(boss.max_hp)
	
	if boss.has_signal("health_changed"):
		if not boss.health_changed.is_connected(update_health):
			boss.health_changed.connect(update_health)

func setup_health(max_hp: float) -> void:
	health_bar.max_value = max_hp
	damage_bar.max_value = max_hp
	health_bar.value = max_hp
	damage_bar.value = max_hp

func update_health(new_health: float) -> void:
	health_bar.value = new_health
	
	if new_health < damage_bar.value:
		if tween and tween.is_valid():
			tween.kill()
			
		tween = create_tween()
		tween.tween_property(damage_bar, "value", float(new_health), 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(0.2)
	else:
		damage_bar.value = new_health
