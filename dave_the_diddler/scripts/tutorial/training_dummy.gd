class_name TrainingDummy
extends StaticBody2D

## Tutorial listens for health updates to refresh the dummy's HUD bar.
signal health_changed(current_health: float, max_health: float)
## Tutorial uses this signal to activate the next dummy or complete its final objective.
signal died

@export_range(1.0, 1000.0, 1.0) var max_health: float = 30.0
@export var display_name: String = "TRAINING DUMMY"

var health: float = 0.0
var _is_destroyed: bool = false
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	health = max_health
	deactivate()


## Enable this objective target and restore its configured health.
func activate() -> void:
	_is_destroyed = false
	health = max_health
	visible = true
	collision_layer = 4
	health_changed.emit(health, max_health)


## Hide inactive tutorial targets and prevent their collision shapes from blocking play.
func deactivate() -> void:
	visible = false
	collision_layer = 0


## Apply damage and emit the defeat signal once health reaches zero.
func take_damage(amount: float) -> void:
	if _is_destroyed or amount <= 0.0:
		return

	var applied_damage := minf(amount, health)
	health = maxf(health - applied_damage, 0.0)
	HelperFunctions.show_damage_number(self, applied_damage, Color(1.0, 0.86, 0.42))
	_visual.color = Color(1.0, 0.45, 0.24, 1.0)
	var flash := create_tween()
	flash.tween_property(_visual, "color", Color(0.86, 0.38, 0.22, 1.0), 0.16)
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_destroyed = true
		died.emit()
