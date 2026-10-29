extends Node2D
## World-space part of the map (province fills, borders, roads, sea routes). It sits behind
## MapView's own drawing and follows pan and zoom through its transform, so panning only moves
## it instead of re-recording thousands of polygons every frame. MapView redraws it when the
## game state, the map mode or the zoom changes (see MapView.refresh()).

var map


func _draw() -> void:
	map._draw_world(self)
