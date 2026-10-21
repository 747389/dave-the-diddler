class_name ShopCard
extends PanelContainer

# Emitted when the scene-authored action button is pressed; Shop connects the id to its purchase handler.
signal action_pressed(item_id: StringName)

@onready var title_label: Label = $Content/Title
@onready var detail_label: Label = $Content/Detail
@onready var action_button: Button = $Content/ActionButton

var _item_id: StringName
var _title_text: String
var _description: String
var _status: String
var _action_text: String
var _is_disabled: bool


func _ready() -> void:
	# The scene-authored purchase button emits the selected resource id to the shop.
	action_button.pressed.connect(_on_action_pressed)
	_apply_configuration()


## Store the resource label and purchase state, applying them when this scene enters the tree.
func configure(
	title_text: String,
	description: String,
	status: String,
	action_text: String,
	is_disabled: bool,
	item_id: StringName
) -> void:
	_title_text = title_text
	_description = description
	_status = status
	_action_text = action_text
	_is_disabled = is_disabled
	_item_id = item_id
	if is_node_ready():
		_apply_configuration()


## Update the fixed scene controls from the data provided by Shop.
func _apply_configuration() -> void:
	title_label.text = "%s   ·   %s" % [_title_text, _status]
	detail_label.text = _description
	action_button.text = _action_text
	action_button.disabled = _is_disabled


func _on_action_pressed() -> void:
	action_pressed.emit(_item_id)
