# scripts/objects/brick.gd
# HP를 가진 벽돌. 사각형과 직각삼각형 두 가지 타입을 지원한다.
# 사각형은 Sprite2D 텍스처, 삼각형은 텍스처 Polygon2D로 렌더링한다.
extends StaticBody2D

signal brick_destroyed(position: Vector2, item: String)

# HP 구간별 벽돌담 타일 텍스처
const TEXTURES := {
	"green": preload("res://assets/images/bricks/tile_brick_green.png"),
	"orange": preload("res://assets/images/bricks/tile_brick_orange.png"),
	"red": preload("res://assets/images/bricks/tile_brick_red.png"),
	"grey": preload("res://assets/images/bricks/tile_brick_grey.png"),
}

# HP 구간별 색상 키
const HP_COLOR_THRESHOLDS := [
	[11, "green"],
	[31, "orange"],
	[999999, "red"],
]

# 삼각형 테두리(줄눈) 색상
const MORTAR_COLORS := {
	"green": Color(0.35, 0.52, 0.14),
	"orange": Color(0.72, 0.47, 0.03),
	"red": Color(0.60, 0.14, 0.13),
	"grey": Color(0.31, 0.31, 0.34),
}

# 직각삼각형 4방향 꼭짓점 (반폭/반높이 기준, setup_triangle에서 스케일)
# dir 0: ◣  dir 1: ◢  dir 2: ◤  dir 3: ◥
const TRI_VERTICES := {
	0: [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1)],
	1: [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	2: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)],
	3: [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1)],
}

# 삼각형 방향별 무게중심 오프셋 (직각 꼭짓점 방향, 반폭/반높이 단위)
const TRI_CENTROID := {
	0: Vector2(-1.0 / 3.0, 1.0 / 3.0),
	1: Vector2(1.0 / 3.0, 1.0 / 3.0),
	2: Vector2(-1.0 / 3.0, -1.0 / 3.0),
	3: Vector2(1.0 / 3.0, -1.0 / 3.0),
}

const TILE_SIZE := 70.0

var hp: int = 1
var _is_destroyed := false
var _is_triangle := false
var _polygon: Polygon2D = null
var _border_polygon: Polygon2D = null
var _hit_tween: Tween = null
var item: String = ""

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
# 타일 텍스처를 삼각형 형태로 UV 매핑하여 벽돌무늬를 표현한다.
func setup_triangle(brick_hp: int, dir: int, cell_size: Vector2) -> void:
	hp = brick_hp
	_is_triangle = true
	# 사각형 스프라이트와 충돌체를 제거한다.
	sprite.visible = false
	$CollisionShape2D.disabled = true
	$CollisionShape2D.queue_free()

	var hw := cell_size.x * 0.5
	var hh := cell_size.y * 0.5
	var base_verts: Array = TRI_VERTICES[dir]
	var verts: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in base_verts:
		verts.append(Vector2(v.x * hw, v.y * hh))

	# 테두리 Polygon2D (줄눈 색상, 풀사이즈)
	_border_polygon = Polygon2D.new()
	_border_polygon.polygon = verts
	_border_polygon.color = MORTAR_COLORS["green"]
	add_child(_border_polygon)

	# 메인 Polygon2D (텍스처 매핑, 약간 안쪽으로 축소)
	_polygon = Polygon2D.new()
	var centroid := Vector2.ZERO
	for v in verts:
		centroid += v
	centroid /= verts.size()
	var inner_verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for v in verts:
		var shrunk := centroid + (v - centroid) * 0.92
		inner_verts.append(shrunk)
		# 꼭짓점 위치를 텍스처 좌표로 변환한다.
		uvs.append(Vector2(
			(v.x + hw) / (2.0 * hw) * TILE_SIZE,
			(v.y + hh) / (2.0 * hh) * TILE_SIZE
		))
	_polygon.polygon = inner_verts
	_polygon.texture = TEXTURES["green"]
	_polygon.uv = uvs
	_polygon.color = Color.WHITE
	add_child(_polygon)

	# 충돌 폴리곤
	var col_poly := CollisionPolygon2D.new()
	col_poly.polygon = verts
	add_child(col_poly)

	# HP 라벨이 폴리곤 위에 그려지도록 최상위로 올린다.
	move_child(hp_label, -1)

	# HP 라벨을 직각 꼭짓점 방향(무게중심)으로 이동한다.
	var tri_center := Vector2(TRI_CENTROID[dir])
	var label_cx := tri_center.x * hw
	var label_cy := tri_center.y * hh
	hp_label.offset_left = -25.0 + label_cx
	hp_label.offset_right = 25.0 + label_cx
	hp_label.offset_top = -12.0 + label_cy
	hp_label.offset_bottom = 12.0 + label_cy

	# HP 설정
	if hp == -1:
		_update_triangle_color("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()


# 공에 맞았을 때 호출된다. 이중 파괴 방지를 위해 플래그로 보호한다.
func hit() -> void:
	if hp == -1 or _is_destroyed:
		return
	hp -= 1
	if hp <= 0:
		_is_destroyed = true
		brick_destroyed.emit(global_position, item)
		queue_free()
	else:
		_update_color_by_hp()
		_update_hp_label()
		_play_hit_effect()


# 미사일에 의한 즉시 파괴. HP를 무시하고 파괴한다.
func destroy_by_missile() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	brick_destroyed.emit(global_position, item)
	queue_free()


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


# 사각형 벽돌 텍스처를 교체한다.
func _update_texture(color_key: String) -> void:
	if sprite and TEXTURES.has(color_key):
		sprite.texture = TEXTURES[color_key]


# 삼각형 벽돌 텍스처와 줄눈 색상을 교체한다.
func _update_triangle_color(color_key: String) -> void:
	if _polygon and TEXTURES.has(color_key):
		_polygon.texture = TEXTURES[color_key]
	if _border_polygon and MORTAR_COLORS.has(color_key):
		_border_polygon.color = MORTAR_COLORS[color_key]


# HP 라벨을 갱신한다.
func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(hp)


# 피격 시 플래시 + 스케일 펀치 효과를 재생한다.
func _play_hit_effect() -> void:
	# 이전 효과가 진행 중이면 즉시 중단
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	scale = Vector2.ONE

	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)

	# 1) 흰색 플래시 — 밝아졌다 원래 색으로
	if _is_triangle and _polygon:
		_polygon.modulate = Color(2.5, 2.5, 2.5, 1.0)
		_hit_tween.tween_property(_polygon, "modulate", Color.WHITE, 0.12)
	elif sprite:
		sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		_hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)

	# 2) 스케일 펀치 — 살짝 커졌다 원래 크기로 (탄력감)
	scale = Vector2(1.15, 1.15)
	_hit_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
