class_name DamageNumber
extends Node2D

@export var rise_duration: float = 0.68

var _amount: int = 0
var _tint: Color = Color(1.0, 0.88, 0.48)
var _spawn_position: Vector2 = Vector2.ZERO
@onready var _label: Label = $Label


## Apply the rounded damage value and tint before this node enters the scene tree.
func configure(amount: int, tint: Color, world_position: Vector2) -> void:
	_amount = amount
	_tint = tint
	_spawn_position = world_position


func _ready() -> void:
	# Float upward with a small random horizontal drift, then remove the finished label.
	global_position = _spawn_position
	_label.text = str(_amount)
	_label.add_theme_color_override("font_color", _tint)
	var end_position := global_position + Vector2(randf_range(-22.0, 22.0), -randf_range(34.0, 62.0))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_position, rise_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, rise_duration).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
