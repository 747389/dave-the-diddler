extends BossRobot

var _second_ripple_delay: float = 0.0


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	begin_major_attack()


func _execute_major_attack(_player: Node2D, _direction: float) -> void:
	_spawn_ripple_pair()
	_second_ripple_delay = 0.42


func _update_custom_motion(delta: float, _player: Node2D, direction: float) -> void:
	if _second_ripple_delay > 0.0:
		_second_ripple_delay -= delta
		if _second_ripple_delay <= 0.0:
			_spawn_ripple_pair()
	velocity.x = direction * move_speed * 0.35


## Sweep low collision ripples away from the boss so its head is the safe spot.
func _spawn_ripple_pair() -> void:
	var ripple_color := Color(1.0, 0.36, 0.24, 0.95)
	# Three low horizontal bands leave the boss-head height as the safest pocket.
	for vertical_offset in [20.0, -100.0, -220.0]:
		var ripple_line := global_position + Vector2(0.0, vertical_offset)
		spawn_rectangle_hazard(
			ripple_line, Vector2(54.0, 18.0), ripple_color, attack_damage,
			Vector2(-300.0, 0.0), 3.8
		)
		spawn_rectangle_hazard(
			ripple_line, Vector2(54.0, 18.0), ripple_color, attack_damage,
			Vector2(300.0, 0.0), 3.8
		)
