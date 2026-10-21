extends BossRobot

const DASH_STEP_INTERVAL: float = 0.02
const DASH_PROGRESS_STEPS: Array[float] = [0.5, 0.8, 0.9, 0.95, 1.0]

var _dash_start: Vector2
var _dash_target: Vector2
var _dash_step_index: int = 0
var _dash_step_time_left: float = 0.0
var _is_dashing: bool = false
var _dash_direction: float = 1.0


func _try_start_attack(_player: Node2D, direction: float) -> void:
	if _is_dashing:
		return
	if begin_major_attack():
		_dash_direction = direction if not is_zero_approx(direction) else 1.0


## Teleport through five decelerating positions and leave one damaging Area2D over the full path.
func _execute_major_attack(player: Node2D, _direction: float) -> void:
	if player == null:
		return
	_dash_start = global_position
	var target_x := clampf(player.global_position.x + _dash_direction * 100.0, -470.0, 470.0)
	_dash_target = Vector2(target_x, global_position.y)
	_spawn_dash_path_hazard()
	_is_dashing = true
	_dash_step_index = 0
	_dash_step_time_left = DASH_STEP_INTERVAL


func _update_custom_motion(delta: float, _player: Node2D, _direction: float) -> void:
	velocity.x = 0.0
	if not _is_dashing:
		return
	_dash_step_time_left -= delta
	while _dash_step_time_left <= 0.0 and _dash_step_index < DASH_PROGRESS_STEPS.size():
		global_position = _dash_start.lerp(_dash_target, DASH_PROGRESS_STEPS[_dash_step_index])
		_dash_step_index += 1
		_dash_step_time_left += DASH_STEP_INTERVAL
	if _dash_step_index >= DASH_PROGRESS_STEPS.size():
		_is_dashing = false


## Cover Bolt's entire teleport route with a brief damaging rectangle before the first jump.
func _spawn_dash_path_hazard() -> void:
	var path_width := absf(_dash_target.x - _dash_start.x)
	if path_width <= 1.0:
		return
	spawn_rectangle_hazard(
		(_dash_start + _dash_target) * 0.5,
		Vector2(path_width + 44.0, 54.0),
		Color(1.0, 0.43, 0.26, 0.55),
		attack_damage,
		Vector2.ZERO,
		0.14
	)
