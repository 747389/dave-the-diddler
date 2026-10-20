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
@export_multiline var ability: String
@export var arena_color: Color = Color.WHITE
@export var service_id: StringName
@export var service_title: String
@export_multiline var service_hint: String
