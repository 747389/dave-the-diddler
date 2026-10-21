class_name Player
extends CharacterBody2D

const MOVE_LEFT_ACTION := "move_left"
const MOVE_RIGHT_ACTION := "move_right"
const JUMP_ACTION := "jump"
const DASH_ACTION := "dash"
const WEAPON_SWAP_ACTION := "weapon_swap"
const LIGHT_ATTACK_ACTION := "light_attack"
const HEAVY_ATTACK_ACTION := "heavy_attack"
const SPECIAL_1_ACTION := "special_1"
const SPECIAL_2_ACTION := "special_2"
const SPECIAL_3_ACTION := "special_3"
const HEAVY_ATTACK_MULTIPLIER: float = 2.0
const DASH_IFRAME_TAIL: float = 0.08
const OVERDRIVE_IFRAME_DURATION: float = 0.7
const GUN_COOLDOWN: float = 0.5
const GUN_BASE_DAMAGE: float = 14.0
const GUN_BASE_CRIT_CHANCE: float = 0.01
const GUN_BASE_CRIT_MULTIPLIER: float = 2.0
const PLAYER_BULLET_SCENE: PackedScene = preload("res://scenes/player/attacks/player_bullet.tscn")

## Emitted on spawn, damage, and healing; Arena connects it to the player health HUD.
signal health_changed(current_health: float, max_health: float)
## Emitted once when health reaches zero; Arena uses it to open the post-death shop.
signal died
## Tutorial records confirmed light and heavy sword hits on its melee target.
signal melee_attack_landed(target: Node2D, is_heavy: bool)

@export var move_speed: float = 260.0
@export var jump_velocity: float = -410.0
@export var double_jump_unlocked: bool = false
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65
@export var max_health: float = 100.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 0.4
@export var gun_cooldown: float = GUN_COOLDOWN
@export var gun_damage: float = GUN_BASE_DAMAGE

var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var health: float = 100.0
var _jumps_used: int = 0
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dashes_used: int = 0
var _bonus_air_dashes: int = 0
var _facing_direction: float = 1.0
var _attack_cooldown_left: float = 0.0
var _invulnerability_time_left: float = 0.0
var _special_cooldowns: Dictionary = {&"emp": 0.0, &"repair": 0.0, &"overclock": 0.0}
var _overclock_time_left: float = 0.0
var _temporary_shield_time: float = 0.0
var _is_dead: bool = false
var _equipped_weapon: StringName = &"gun"
@onready var _visual: CanvasItem = $Visual
@onready var _gun_visual: Polygon2D = $GunVisual
@onready var _sword_visual: Polygon2D = $SwordVisual
@onready var _movement_particles: CPUParticles2D = $MovementParticles


func _enter_tree() -> void:
	_ensure_input_actions()


## Apply purchased stats and carry forward health and one-use stage bonuses.
func _ready() -> void:
	# Apply purchased stats, then restore carried health and one-use stage bonuses.
	move_speed *= HelperFunctions.get_upgrade_value(&"speed")
	jump_velocity *= HelperFunctions.get_upgrade_value(&"jump")
	dash_speed *= HelperFunctions.get_upgrade_value(&"dash")
	dash_duration *= HelperFunctions.get_upgrade_value(&"dash_length")
	var damage_multiplier := HelperFunctions.get_upgrade_value(&"damage")
	attack_damage *= damage_multiplier
	gun_damage *= damage_multiplier
	attack_cooldown /= HelperFunctions.get_upgrade_value(&"attack_speed")
	gun_damage += HelperFunctions.get_upgrade_value(&"gun_damage")
	gun_cooldown /= HelperFunctions.get_upgrade_value(&"gun_fire_rate")
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
	_update_weapon_visual()
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
	_invulnerability_time_left = maxf(_invulnerability_time_left - delta, 0.0)
	collision_layer = 0 if _invulnerability_time_left > 0.0 else 2
	_overclock_time_left = maxf(_overclock_time_left - delta, 0.0)
	_temporary_shield_time = maxf(_temporary_shield_time - delta, 0.0)
	for ability_id in _special_cooldowns:
		_special_cooldowns[ability_id] = maxf(float(_special_cooldowns[ability_id]) - delta, 0.0)
	_read_movement_input()
	_update_weapon_visual()
	_try_jump()
	_try_dash()
	_try_attacks()
	_try_special_abilities()
	_update_velocity(delta)
	move_and_slide()
	_update_movement_particles()
	_update_invulnerability_visual()


func unlock_double_jump() -> void:
	double_jump_unlocked = true


func take_damage(amount: float) -> void:
	# Armor and a temporary shield stack by taking the stronger reduction only.
	if _is_dead or amount <= 0.0 or _invulnerability_time_left > 0.0:
		return
	var damage_reduction := clampf(HelperFunctions.get_upgrade_value(&"armor"), 0.0, 0.6)
	if _temporary_shield_time > 0.0:
		damage_reduction = maxf(damage_reduction, 0.75)
	var actual_damage := minf(health, amount * (1.0 - damage_reduction))
	health = maxf(health - actual_damage, 0.0)
	HelperFunctions.show_damage_number(self, actual_damage, Color(1.0, 0.35, 0.38))
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_dead = true
		_movement_particles.emitting = false
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


## Swap weapons with Tab; share one attack lockout so light and heavy cannot bypass each other.
func _try_attacks() -> void:
	if Input.is_action_just_pressed(WEAPON_SWAP_ACTION):
		_equipped_weapon = &"sword" if _equipped_weapon == &"gun" else &"gun"
		_update_weapon_visual()
	if _attack_cooldown_left > 0.0:
		return
	# Heavy input wins if both mouse buttons are pressed in the same frame.
	if Input.is_action_just_pressed(HEAVY_ATTACK_ACTION):
		# The gun has no heavy attack; M2 is reserved for the sword's heavy strike.
		if _equipped_weapon == &"gun":
			return
		var heavy_damage := attack_damage * HEAVY_ATTACK_MULTIPLIER
		_attack_cooldown_left = attack_cooldown * 2.0
		_perform_attack(heavy_damage, Vector2(1.35, 1.15), true)
		return

	if not Input.is_action_pressed(LIGHT_ATTACK_ACTION):
		return
	if _equipped_weapon == &"gun":
		_fire_gun()
		return
	_attack_cooldown_left = attack_cooldown
	_perform_attack(attack_damage, Vector2.ONE)


## Fire each unlimited-ammo projectile with its own critical roll and upgraded damage multiplier.
func _fire_gun() -> void:
	_attack_cooldown_left = gun_cooldown
	var critical_chance := GUN_BASE_CRIT_CHANCE + HelperFunctions.get_upgrade_value(&"gun_crit_chance")
	var critical_multiplier := GUN_BASE_CRIT_MULTIPLIER + HelperFunctions.get_upgrade_value(&"gun_crit_damage")
	var muzzle_position := _gun_visual.to_global(Vector2(12.0, 0.0))
	var aim_direction := muzzle_position.direction_to(get_global_mouse_position())
	if aim_direction.is_zero_approx():
		aim_direction = Vector2(_facing_direction, 0.0)
	var directions: Array[Vector2] = [aim_direction]
	if HelperFunctions.is_ability_unlocked(&"double_shot"):
		directions = [aim_direction.rotated(-0.045), aim_direction.rotated(0.045)]
	for direction in directions:
		var shot := PLAYER_BULLET_SCENE.instantiate() as Area2D
		if shot == null:
			continue
		get_tree().current_scene.add_child(shot)
		shot.global_position = muzzle_position
		var shot_damage := gun_damage
		if randf() < critical_chance:
			shot_damage *= critical_multiplier
		shot.call("launch", direction.normalized(), shot_damage)


func _perform_attack(damage: float, area_scale: Vector2, is_heavy: bool = false) -> bool:
	# Move and size the melee hitbox before querying current overlaps.
	var attack_area := $AttackArea as Area2D
	attack_area.position.x = 34.0 * _facing_direction
	attack_area.scale = area_scale
	var hit_target := false
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			melee_attack_landed.emit(body, is_heavy)
			body.call("take_damage", damage)
			hit_target = true
	return hit_target


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
	_invulnerability_time_left = maxf(_invulnerability_time_left, OVERDRIVE_IFRAME_DURATION)
	collision_layer = 0


func _read_movement_input() -> void:
	# Overclock scales movement while preserving dash velocity and facing direction.
	var direction := Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	var effective_speed := move_speed * (1.5 if _overclock_time_left > 0.0 else 1.0)
	if not is_zero_approx(direction):
		_facing_direction = signf(direction)
		_update_weapon_visual()
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
	_update_weapon_visual()
	velocity = Vector2(_facing_direction * dash_speed, 0.0)
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_dashes_used += 1
	_invulnerability_time_left = maxf(
		_invulnerability_time_left,
		dash_duration + DASH_IFRAME_TAIL
	)
	collision_layer = 0


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
	_add_key_action(DASH_ACTION, KEY_SHIFT)
	_add_key_action(WEAPON_SWAP_ACTION, KEY_TAB)
	_add_mouse_action(LIGHT_ATTACK_ACTION, MOUSE_BUTTON_LEFT)
	_add_mouse_action(HEAVY_ATTACK_ACTION, MOUSE_BUTTON_RIGHT)
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


## Register a mouse button for an action without disturbing user-configured bindings.
func _add_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


## Keep the scene emitter running continuously while the player is moving or airborne.
func _update_movement_particles() -> void:
	_movement_particles.emitting = not _is_dead and (not is_on_floor() or absf(velocity.x) >= 45.0)


func _update_invulnerability_visual() -> void:
	if _invulnerability_time_left <= 0.0:
		_visual.modulate.a = 1.0
		return
	var blink_phase := floori(float(Time.get_ticks_msec()) / 80.0)
	_visual.modulate.a = 0.5 if blink_phase % 2 == 0 else 1.0


## Show the equipped weapon and keep it facing the same direction as the player.
func _update_weapon_visual() -> void:
	var target_in_player_space := to_local(get_global_mouse_position())
	var aim_offset := target_in_player_space - _gun_visual.position
	_gun_visual.rotation = aim_offset.angle()
	_gun_visual.scale = Vector2.ONE
	_sword_visual.scale = Vector2(_facing_direction, 1.0)
	_gun_visual.visible = _equipped_weapon == &"gun"
	_sword_visual.visible = _equipped_weapon == &"sword"
