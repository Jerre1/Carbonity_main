extends Node2D

var hover:bool
var poos:Vector2i
@onready var builder = $"../../Builder"


func _process(delta):
	if Input.is_action_just_pressed("build") and hover:
		builder.map.cash += 50
		builder.update_cash()
		builder.bubble_dict[poos] = "none"


func _on_area_2d_mouse_entered():
	hover = true

func _on_area_2d_mouse_exited():
	hover = false
