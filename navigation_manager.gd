extends Node

@onready var player: Player = %Player

const scene_level01 = preload("res://levels/level_01.tscn")
const scene_level02 = preload ("res://levels/level_02.tscn")
const scene_level03 = preload ("res://levels/level_03.tscn")


signal on_trigger_player_spawn

var spawn_door_tag

func go_to_level(level_tag, destination_tag):
	var scene_to_load
	
	match level_tag:
		"level_01":
			scene_to_load = scene_level01
		"level_02":
			scene_to_load = scene_level02
		"level_03":
			scene_to_load = scene_level03
			
	if scene_to_load != null:
		TransitionScreen.transition()
		await TransitionScreen.on_transition_finished
		spawn_door_tag = destination_tag
		get_tree().change_scene_to_packed(scene_to_load)

func trigger_player_spawn(position: Vector2, _direction: String):
	on_trigger_player_spawn.emit(position)
	
