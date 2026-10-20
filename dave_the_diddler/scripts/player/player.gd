class_name Player
extends CharacterBody2D

const MOVE_LEFT_ACTION := "move_left"
const MOVE_RIGHT_ACTION := "move_right"
const JUMP_ACTION := "jump"
const DASH_ACTION := "dash"
const ATTACK_ACTION := "attack"
const SPECIAL_1_ACTION := "special_1"
const SPECIAL_2_ACTION := "special_2"
const SPECIAL_3_ACTION := "special_3"

## Emitted on spawn, damage, and healing; Arena connects it to the player health HUD.
signal health_changed(current_health: float, max_health: float)
## Emitted once when health reaches zero; Arena uses it to open the post-death shop.
signal died

@export var move_speed: float = 260.0
@export var jump_velocity: float = -500.0
@export var double_jump_unlocked: bool = false
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65
@export var max_health: float = 100.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 0.4

var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var health: float = 100.0
var _jumps_used: int = 0
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dashes_used: int = 0
var _bonus_air_dashes: int = 0
var _facing_direction: float = 1.0
var _attack_cooldown_left: float = 0.0
var _special_cooldowns: Dictionary = {&"emp": 0.0, &"repair": 0.0, &"overclock": 0.0}
var _overclock_time_left: float = 0.0
var _temporary_shield_time: float = 0.0
var _is_dead: bool = false


func _enter_tree() -> void:
	_ensure_input_actions()


## Apply purchased stats and carry forward health and one-use stage bonuses.
func _ready() -> void:
	# Apply purchased stats, then restore carried health and one-use stage bonuses.
	move_speed *= HelperFunctions.get_upgrade_value(&"speed")
	jump_velocity *= HelperFunctions.get_upgrade_value(&"jump")
	dash_speed *= HelperFunctions.get_upgrade_value(&"dash")
	dash_duration *= HelperFunctions.get_upgrade_value(&"dash_length")
	attack_damage *= HelperFunctions.get_upgrade_value(&"damage")
	attack_cooldown /= HelperFunctions.get_upgrade_value(&"attack_speed")
	max_health += HelperFunctions.get_upgrade_value(&"max_health")
	health = max_health
	if Global.carried_player_health > 0.0:
		health = minf(Global.carried_player_health, max_health)
	Global.carried_player_health = -1.0
	double_jump_unlocked = HelperFunctions.is_ability_unlocked(&"double_jump")
	_bonus_air_dashes = Global.bonus_air_dashes
	Global.bonus_air_dashes = 0
	_temporary_shield_time = Global.stage_start_shield
	Global.stage_start_shield = 0.0
	health_changed.emit(health, max_health)


## Update cooldowns and input-driven movement, then resolve the player's motion.
func _physics_process(delta: float) -> void:
	# Process input and timers before moving so dashes and abilities share one update step.
	if _is_dead:
		return
	if is_on_floor():
		_jumps_used = 0
		_dashes_used = 0

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_overclock_time_left = maxf(_overclock_time_left - delta, 0.0)
	_temporary_shield_time = maxf(_temporary_shield_time - delta, 0.0)
	for ability_id in _special_cooldowns:
		_special_cooldowns[ability_id] = maxf(float(_special_cooldowns[ability_id]) - delta, 0.0)
	_read_movement_input()
	_try_jump()
	_try_dash()
	_try_attack()
	_try_special_abilities()
	_update_velocity(delta)
	move_and_slide()


func unlock_double_jump() -> void:
	double_jump_unlocked = true


func take_damage(amount: float) -> void:
	# Armor and a temporary shield stack by taking the stronger reduction only.
	if _is_dead or amount <= 0.0:
		return
	var damage_reduction := clampf(HelperFunctions.get_upgrade_value(&"armor"), 0.0, 0.6)
	if _temporary_shield_time > 0.0:
		damage_reduction = maxf(damage_reduction, 0.75)
	health = maxf(health - amount * (1.0 - damage_reduction), 0.0)
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_dead = true
		died.emit()


func restore_health() -> void:
	health = max_health
	if Global.stage_cleared:
		Global.carried_player_health = health
	health_changed.emit(health, max_health)


func refresh_dash() -> void:
	_dash_cooldown_left = 0.0
	_dashes_used = 0


func grant_temporary_shield(duration: float) -> void:
	# Preserve the strongest shield duration so repeated service effects do not shorten it.
	_temporary_shield_time = maxf(_temporary_shield_time, duration)
	if Global.stage_cleared:
		Global.stage_start_shield = maxf(Global.stage_start_shield, duration)


func _try_attack() -> void:
	# The attack area is moved toward the facing direction before checking overlaps.
	if not Input.is_action_just_pressed(ATTACK_ACTION) or _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = attack_cooldown
	$AttackArea.position.x = 34.0 * _facing_direction
	for body in $AttackArea.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.call("take_damage", attack_damage)


func _try_special_abilities() -> void:
	# Each action delegates its unlock and cooldown checks to its ability handler.
	if Input.is_action_just_pressed(SPECIAL_1_ACTION):
		_use_emp()
	if Input.is_action_just_pressed(SPECIAL_2_ACTION):
		_use_repair()
	if Input.is_action_just_pressed(SPECIAL_3_ACTION):
		_use_overclock()


func _use_emp() -> void:
	# EMP damages every robot inside its radius, including bosses.
	if not HelperFunctions.is_ability_unlocked(&"emp") or _special_cooldowns[&"emp"] > 0.0:
		return
	_special_cooldowns[&"emp"] = 5.0
	for robot_node in get_tree().get_nodes_in_group("robots"):
		var robot := robot_node as Node2D
		if robot == null:
			continue
		if global_position.distance_to(robot.global_position) <= 180.0:
			robot.call("take_damage", 45.0 * HelperFunctions.get_upgrade_value(&"damage"))


func _use_repair() -> void:
	if not HelperFunctions.is_ability_unlocked(&"repair") or _special_cooldowns[&"repair"] > 0.0:
		return
	if health >= max_health:
		return
	_special_cooldowns[&"repair"] = 8.0
	health = minf(health + 40.0, max_health)
	health_changed.emit(health, max_health)


func _use_overclock() -> void:
	if not HelperFunctions.is_ability_unlocked(&"overclock") or _special_cooldowns[&"overclock"] > 0.0:
		return
	_special_cooldowns[&"overclock"] = 12.0
	_overclock_time_left = 5.0


func _read_movement_input() -> void:
	# Overclock scales movement while preserving dash velocity and facing direction.
	var direction := Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	var effective_speed := move_speed * (1.5 if _overclock_time_left > 0.0 else 1.0)
	if not is_zero_approx(direction):
		_facing_direction = signf(direction)
		if _dash_time_left <= 0.0:
			velocity.x = direction * effective_speed
	elif _dash_time_left <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, effective_speed)


func _try_jump() -> void:
	# Ground contact resets the counter in physics processing; upgrades raise the air limit.
	if not Input.is_action_just_pressed(JUMP_ACTION):
		return

	var jump_limit := 2 if double_jump_unlocked else 1
	if _jumps_used >= jump_limit:
		return

	velocity.y = jump_velocity
	_jumps_used += 1


## Launch a dash when its cooldown and remaining air-dash charges allow it.
func _try_dash() -> void:
	# Extra dash charges apply in air; cooldown and charge count are checked before launch.
	if not Input.is_action_just_pressed(DASH_ACTION):
		return
	if _dash_cooldown_left > 0.0 or _dashes_used >= 1 + _bonus_air_dashes:
		return

	var direction := Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	if is_zero_approx(direction):
		direction = _facing_direction

	_facing_direction = signf(direction)
	velocity = Vector2(_facing_direction * dash_speed, 0.0)
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_dashes_used += 1


func _update_velocity(delta: float) -> void:
	# A dash owns horizontal velocity until it ends; gravity resumes afterward.
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)
		return
	if not is_on_floor():
		velocity.y += _gravity * delta


func _ensure_input_actions() -> void:
	# Player controls are registered before _ready so input is available on first frame.
	_add_key_action(MOVE_LEFT_ACTION, KEY_A, KEY_LEFT)
	_add_key_action(MOVE_RIGHT_ACTION, KEY_D, KEY_RIGHT)
	_add_key_action(JUMP_ACTION, KEY_SPACE, KEY_W, KEY_UP)
	_add_key_action(DASH_ACTION, KEY_Q)
	_add_key_action(ATTACK_ACTION, KEY_F)
	_add_key_action(SPECIAL_1_ACTION, KEY_Z)
	_add_key_action(SPECIAL_2_ACTION, KEY_X)
	_add_key_action(SPECIAL_3_ACTION, KEY_C)


## Add each provided key only if that action does not already contain the event.
func _add_key_action(
	action_name: StringName,
	primary_key: Key,
	secondary_key: Key = KEY_NONE,
	tertiary_key: Key = KEY_NONE
) -> void:
	# Support alternate keys without duplicating events already configured in the project.
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in [primary_key, secondary_key, tertiary_key]:
		if keycode == KEY_NONE:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)
