# scripts/objects/brick.gd
# HP를 가진 벽돌. 공에 맞으면 HP가 1 감소한다.
# HP에 따라 텍스처 색상이 바뀌고, 중앙에 HP 숫자를 표시한다.
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

var hp: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HPLabel


# 벽돌의 HP와 텍스처를 초기화한다.
func setup(brick_hp: int) -> void:
	hp = brick_hp
	if hp == -1:
		_update_texture("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()


# 공에 맞았을 때 호출된다. HP를 1 감소시키고 파괴 여부를 판정한다.
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


# HP에 따라 텍스처 색상을 갱신한다.
func _update_color_by_hp() -> void:
	_update_texture(_get_color_key())


# 텍스처를 교체한다.
func _update_texture(color_key: String) -> void:
	if sprite and TEXTURES.has(color_key):
		sprite.texture = TEXTURES[color_key]


# HP 라벨을 갱신한다.
func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(hp)


# 피격 시 흰색 플래시 효과를 재생한다.
func _play_hit_effect() -> void:
	var tween := create_tween()
	sprite.modulate = Color.WHITE * 2.0
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
