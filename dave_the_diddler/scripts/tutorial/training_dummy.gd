class_name TrainingDummy
extends StaticBody2D

## Tutorial listens for health updates to refresh the dummy's HUD bar.
signal health_changed(current_health: float, max_health: float)
## Tutorial listens for this signal to complete its final objective.
signal died

@export var max_health: float = 50.0

var health: float = 0.0
var _is_destroyed: bool = false
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


## Apply the player's normal attack and remove the dummy when its health is depleted.
func take_damage(amount: float) -> void:
	if _is_destroyed or amount <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	_visual.color = Color(1.0, 0.45, 0.24, 1.0)
	var flash := create_tween()
	flash.tween_property(_visual, "color", Color(0.86, 0.38, 0.22, 1.0), 0.16)
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_destroyed = true
		died.emit()
		queue_free()
