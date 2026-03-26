# scripts/objects/brick.gd
# HP를 가진 벽돌. 사각형과 직각삼각형 두 가지 타입을 지원한다.
# HP에 따라 색상이 바뀌고, 중앙에 HP 숫자를 표시한다.
extends StaticBody2D

signal brick_destroyed(position: Vector2)

const TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_14.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_14.png"),
	"red": preload("res://assets/images/bricks/tileRed_14.png"),
	"grey": preload("res://assets/images/bricks/tileGrey_14.png"),
}

# HP 구간별 색상 키
const HP_COLOR_THRESHOLDS := [
	[11, "green"],
	[31, "orange"],
	[999999, "red"],
]

# Polygon2D용 단색 (Kenney 색상 근사)
const FILL_COLORS := {
	"green": Color(0.55, 0.74, 0.23),
	"orange": Color(0.89, 0.55, 0.12),
	"red": Color(0.76, 0.24, 0.24),
	"grey": Color(0.45, 0.45, 0.50),
}
const BORDER_COLORS := {
	"green": Color(0.38, 0.55, 0.12),
	"orange": Color(0.70, 0.38, 0.05),
	"red": Color(0.55, 0.14, 0.14),
	"grey": Color(0.30, 0.30, 0.35),
}

# 직각삼각형 4방향 꼭짓점 (반폭/반높이 기준, setup_triangle에서 스케일)
# dir 0: ◣  dir 1: ◢  dir 2: ◤  dir 3: ◥
const TRI_VERTICES := {
	0: [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1)],
	1: [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	2: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)],
	3: [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1)],
}

var hp: int = 1
var _is_triangle := false
var _polygon: Polygon2D = null
var _border_polygon: Polygon2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HPLabel


# 사각형 벽돌 초기화.
func setup(brick_hp: int) -> void:
	hp = brick_hp
	_is_triangle = false
	if hp == -1:
		_update_texture("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()


# 직각삼각형 벽돌 초기화. cell_size로 크기를 맞추고 dir로 방향을 정한다.
func setup_triangle(brick_hp: int, dir: int, cell_size: Vector2) -> void:
	hp = brick_hp
	_is_triangle = true
	# 사각형 스프라이트와 충돌체를 숨긴다.
	sprite.visible = false
	$CollisionShape2D.set_deferred("disabled", true)

	var hw := cell_size.x * 0.5
	var hh := cell_size.y * 0.5
	var base_verts: Array = TRI_VERTICES[dir]
	var verts: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in base_verts:
		verts.append(Vector2(v.x * hw, v.y * hh))

	# 테두리 Polygon2D (약간 큰 크기로 아래에 깔기)
	_border_polygon = Polygon2D.new()
	var border_verts: PackedVector2Array = PackedVector2Array()
	var border_inset := 2.0
	for v: Vector2 in base_verts:
		border_verts.append(Vector2(v.x * hw, v.y * hh))
	_border_polygon.polygon = border_verts
	_border_polygon.color = BORDER_COLORS["green"]
	add_child(_border_polygon)

	# 메인 Polygon2D (약간 안쪽)
	_polygon = Polygon2D.new()
	var inner_verts: PackedVector2Array = PackedVector2Array()
	# 삼각형 무게중심 기준으로 안쪽으로 축소
	var centroid := Vector2.ZERO
	for v in verts:
		centroid += v
	centroid /= verts.size()
	for v in verts:
		var shrunk := centroid + (v - centroid) * 0.88
		inner_verts.append(shrunk)
	_polygon.polygon = inner_verts
	_polygon.color = FILL_COLORS["green"]
	add_child(_polygon)

	# 충돌 폴리곤
	var col_poly := CollisionPolygon2D.new()
	col_poly.polygon = verts
	add_child(col_poly)

	# HP 설정
	if hp == -1:
		_update_triangle_color("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()


# 공에 맞았을 때 호출된다.
func hit() -> void:
	if hp == -1:
		return
	hp -= 1
	if hp <= 0:
		brick_destroyed.emit(global_position)
		queue_free()
	else:
		_update_color_by_hp()
		_update_hp_label()
		_play_hit_effect()


# HP 구간에 따른 색상 키를 반환한다.
func _get_color_key() -> String:
	for threshold in HP_COLOR_THRESHOLDS:
		if hp < int(threshold[0]):
			return threshold[1] as String
	return "red"


# HP에 따라 색상을 갱신한다.
func _update_color_by_hp() -> void:
	var key := _get_color_key()
	if _is_triangle:
		_update_triangle_color(key)
	else:
		_update_texture(key)


# 사각형 텍스처를 교체한다.
func _update_texture(color_key: String) -> void:
	if sprite and TEXTURES.has(color_key):
		sprite.texture = TEXTURES[color_key]


# 삼각형 Polygon2D 색상을 교체한다.
func _update_triangle_color(color_key: String) -> void:
	if _polygon and FILL_COLORS.has(color_key):
		_polygon.color = FILL_COLORS[color_key]
	if _border_polygon and BORDER_COLORS.has(color_key):
		_border_polygon.color = BORDER_COLORS[color_key]


# HP 라벨을 갱신한다.
func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(hp)


# 피격 시 흰색 플래시 효과를 재생한다.
func _play_hit_effect() -> void:
	if _is_triangle and _polygon:
		var original_color: Color = _polygon.color
		_polygon.color = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_polygon, "color", original_color, 0.1)
	elif sprite:
		var tween := create_tween()
		sprite.modulate = Color.WHITE * 2.0
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
