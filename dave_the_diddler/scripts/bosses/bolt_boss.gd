extends BossRobot

var _charge_direction: float = 1.0
var _charge_time_left: float = 0.0


func _try_start_attack(_player: Node2D, direction: float) -> void:
	if begin_major_attack():
		_charge_direction = direction if not is_zero_approx(direction) else 1.0


func _execute_major_attack(_player: Node2D, _direction: float) -> void:
	_charge_time_left = 0.68


func _update_custom_motion(delta: float, _player: Node2D, direction: float) -> void:
	if _charge_time_left > 0.0:
		_charge_time_left = maxf(_charge_time_left - delta, 0.0)
		velocity.x = _charge_direction * 520.0
		return
	velocity.x = direction * move_speed
