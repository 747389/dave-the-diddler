class_name UpgradeData
extends Resource

@export var key: StringName
@export var display_name: String
@export_multiline var description: String
@export_enum("multiplier", "bonus") var effect_type: String = "multiplier"
@export var effect_per_level: float = 0.0
@export var base_cost: int = 1
@export var cost_growth: float = 1.0
@export var max_level: int = 1
