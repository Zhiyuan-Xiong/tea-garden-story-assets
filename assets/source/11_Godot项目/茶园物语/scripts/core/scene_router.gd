extends Node

signal requested(destination: String, with_loading: bool)
signal modal_requested(kind: String, data: Dictionary)
var current: String = "home"
var transitioning: bool = false
const PATHS: Dictionary = {"home": "res://scenes/areas/home.tscn", "village": "res://scenes/areas/village.tscn", "garden": "res://scenes/areas/garden.tscn", "workshop": "res://scenes/areas/workshop.tscn", "teashop": "res://scenes/areas/teashop.tscn"}

func go(destination: String, with_loading: bool = true) -> void:
	if not PATHS.has(destination) or transitioning:
		return
	requested.emit(destination, with_loading)

func modal(kind: String, data: Dictionary = {}) -> void:
	modal_requested.emit(kind, data)
