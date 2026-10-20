class_name StageData
extends Resource

@export var key: StringName
@export_range(0, 4) var order: int = 0
@export var display_name: String
@export var title: String
@export var health: float = 1.0
@export var speed: float = 1.0
@export var contact_damage: float = 1.0
@export var gear_reward: int = 0
@export var boss_scene: PackedScene
@export var attack_interval: float = 2.4
@export_range(0.1, 1.0, 0.05) var warning_duration: float = 0.35
@export var can_jump: bool = false
@export var can_flash_step: bool = false
@export var flash_step_distance: float = 180.0
@export var attack_damage: float = 18.0
@export_multiline var ability: String
@export var arena_color: Color = Color.WHITE
