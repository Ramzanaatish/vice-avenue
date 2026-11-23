extends Control

## Greybox minimap (S07): draws the district bounds, building
## footprints (from the district JSON) and the player dot.
## A live SubViewport render comes with detailed art (later).

var _bounds := {"min_x": -60.0, "max_x": 60.0, "min_z": -60.0, "max_z": 60.0}
var _buildings: Array = []
var _player: Node3D = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func set_district(district: Dictionary) -> void:
	_bounds = district.get("bounds", _bounds)
	_buildings = district.get("buildings", [])
	queue_redraw()

func set_player(p: Node3D) -> void:
	_player = p

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var w := float(_bounds["max_x"]) - float(_bounds["min_x"])
	var d := float(_bounds["max_z"]) - float(_bounds["min_z"])
	if w <= 0.0 or d <= 0.0:
		return
	for b in _buildings:
		var bx: float = (float(b["x"]) - float(_bounds["min_x"])) / w * size.x
		var bz: float = (float(b["z"]) - float(_bounds["min_z"])) / d * size.y
		var bw: float = float(b["w"]) / w * size.x
		var bd: float = float(b["d"]) / d * size.y
		draw_rect(Rect2(bx - bw / 2.0, bz - bd / 2.0, bw, bd), Color(1, 1, 1, 0.25))
	if _player != null:
		var px: float = (_player.global_position.x - float(_bounds["min_x"])) / w * size.x
		var pz: float = (_player.global_position.z - float(_bounds["min_z"])) / d * size.y
		draw_circle(Vector2(px, pz), 5.0, Color(0.9, 0.65, 0.3))
