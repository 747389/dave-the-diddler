extends BossRobot

enum AttackMode { FLOOR_SLAM, SKY_PILLAR }
enum SkySlamPhase { NONE, OFFSCREEN, TELEGRAPH, DESCENDING }

var _next_attack: int = AttackMode.FLOOR_SLAM
var _floor_jump_pending: bool = false
var _floor_jump_left_ground: bool = false
var _sky_slam_phase: int = SkySlamPhase.NONE
var _sky_slam_time_left: float = 0.0
var _sky_slam_target_x: float = 0.0
var _pillar_indicator: Node2D


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	if _floor_jump_pending or _sky_slam_phase != SkySlamPhase.NONE:
		return
	begin_major_attack()


## Alternate a floor-wide jump shockwave with an off-screen drop through a warned vertical pillar.
func _execute_major_attack(player: Node2D, _direction: float) -> void:
	if _next_attack == AttackMode.FLOOR_SLAM:
		velocity.y = jump_velocity * 1.35
		_floor_jump_pending = true
		_floor_jump_left_ground = false
		_next_attack = AttackMode.SKY_PILLAR
		return
	_start_sky_slam(player)
	_next_attack = AttackMode.FLOOR_SLAM


## Run Hopper's airborne state machine while keeping it stationary between major jumps.
func _update_custom_motion(delta: float, player: Node2D, _direction: float) -> void:
	velocity.x = 0.0
	_update_floor_slam(player)
	_update_sky_slam(delta, player)


## Create a floor-wide Area2D only when the player is standing on the ground at Hopper's landing.
func _update_floor_slam(player: Node2D) -> void:
	if not _floor_jump_pending:
		return
	if not is_on_floor():
		_floor_jump_left_ground = true
		return
	if not _floor_jump_left_ground:
		return
	_floor_jump_pending = false
	HelperFunctions.screen_shake(self, 9.0, 0.18)
	if player != null and player.is_on_floor():
		spawn_rectangle_hazard(
			Vector2(0.0, global_position.y + 20.0),
			Vector2(1100.0, 70.0),
			Color(1.0, 0.46, 0.2, 0.8),
			attack_damage,
			Vector2.ZERO,
			0.14
		)


## Hide above the arena, warn a player-tracked column, then drive Hopper through that column.
func _update_sky_slam(delta: float, player: Node2D) -> void:
	match _sky_slam_phase:
		SkySlamPhase.NONE:
			return
		SkySlamPhase.OFFSCREEN:
			_sky_slam_time_left -= delta
			if _sky_slam_time_left > 0.0:
				return
			_sky_slam_target_x = _predict_player_x(player)
			global_position = Vector2(_sky_slam_target_x, -480.0)
			visible = true
			collision_layer = 4
			_show_pillar_indicator()
			_sky_slam_phase = SkySlamPhase.TELEGRAPH
			_sky_slam_time_left = 0.4
		SkySlamPhase.TELEGRAPH:
			_sky_slam_time_left -= delta
			if _sky_slam_time_left > 0.0:
				return
			_clear_pillar_indicator()
			velocity.y = 1050.0
			_sky_slam_phase = SkySlamPhase.DESCENDING
		SkySlamPhase.DESCENDING:
			if not is_on_floor():
				return
			_sky_slam_phase = SkySlamPhase.NONE
			HelperFunctions.screen_shake(self, 14.0, 0.24)
			spawn_rectangle_hazard(
				Vector2(_sky_slam_target_x, 0.0),
				Vector2(100.0, 820.0),
				Color(1.0, 0.18, 0.24, 0.85),
				attack_damage * 1.25,
				Vector2.ZERO,
				0.16
			)


## Begin the off-screen phase, temporarily disabling Hopper's body until its warning appears.
func _start_sky_slam(_player: Node2D) -> void:
	velocity = Vector2.ZERO
	visible = false
	collision_layer = 0
	_sky_slam_phase = SkySlamPhase.OFFSCREEN
	_sky_slam_time_left = 0.42


## Predict the landing lane from the player's current horizontal movement.
func _predict_player_x(player: Node2D) -> float:
	if player == null:
		return global_position.x
	var predicted_x := player.global_position.x
	if player is CharacterBody2D:
		predicted_x += player.velocity.x * 0.4
	return clampf(predicted_x, -455.0, 455.0)


## Draw the red full-height warning column before the sky slam becomes damaging.
func _show_pillar_indicator() -> void:
	_clear_pillar_indicator()
	var arena := get_tree().current_scene
	if arena == null:
		return
	var indicator := Node2D.new()
	indicator.global_position = Vector2(_sky_slam_target_x, 0.0)
	indicator.z_index = 3
	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.2, 0.24, 0.22)
	fill.polygon = PackedVector2Array([
		Vector2(-50.0, -410.0), Vector2(50.0, -410.0),
		Vector2(50.0, 410.0), Vector2(-50.0, 410.0)
	])
	indicator.add_child(fill)
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.34, 0.38, 0.9)
	outline.points = PackedVector2Array([
		Vector2(-50.0, -410.0), Vector2(50.0, -410.0),
		Vector2(50.0, 410.0), Vector2(-50.0, 410.0), Vector2(-50.0, -410.0)
	])
	indicator.add_child(outline)
	arena.add_child(indicator)
	_pillar_indicator = indicator


func _clear_pillar_indicator() -> void:
	if is_instance_valid(_pillar_indicator):
		_pillar_indicator.queue_free()
	_pillar_indicator = null
