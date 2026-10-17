extends Area2D

@export var zone_color: Color = Color(0.877, 1.0, 0.867, 1.0)
@export var transition_time: float = 1.2

@onready var zone_particles = $LeafParticles
@onready var main_world_color = $"../world_color" 

func _ready() -> void:
	if zone_particles:
		zone_particles.emitting = false
		zone_particles.hide()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if main_world_color and main_world_color.has_method("override_color"):
			main_world_color.override_color(zone_color, transition_time)
		
		if zone_particles:
			zone_particles.show() 
			zone_particles.restart() 
			zone_particles.emitting = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if main_world_color and main_world_color.has_method("restore_natural_time"):
			main_world_color.restore_natural_time(transition_time)
		
		if zone_particles:
			zone_particles.emitting = false
			zone_particles.hide()
