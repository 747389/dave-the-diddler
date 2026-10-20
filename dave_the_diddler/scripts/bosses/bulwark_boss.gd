extends BossRobot

var _second_wall_delay: float = 0.0


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	begin_major_attack()


func _execute_major_attack(_player: Node2D, _direction: float) -> void:
	_spawn_crossing_wall(1.0)
	_second_wall_delay = 0.72


func _update_custom_motion(delta: float, _player: Node2D, direction: float) -> void:
	if _second_wall_delay > 0.0:
		_second_wall_delay -= delta
		if _second_wall_delay <= 0.0:
			_spawn_crossing_wall(-1.0)
	velocity.x = direction * move_speed * 0.3


## Send a tall shield panel across the whole arena for a timed dash-through dodge.
func _spawn_crossing_wall(direction: float) -> void:
	var start_x := 510.0 * direction
	var wall_size := Vector2(48.0, 780.0)
	var wall_tint := Color(1.0, 0.28, 0.3, 0.9)
	spawn_rectangle_hazard(
		Vector2(start_x, 45.0), wall_size, wall_tint, attack_damage,
		Vector2(-direction * 420.0, 0.0), 2.6
	)
