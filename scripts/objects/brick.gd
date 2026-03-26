# scripts/objects/brick.gd
# HP를 가진 벽돌. 공에 맞으면 HP가 감소하고 텍스처가 바뀐다.
# HP가 0이 되면 파괴되며 점수와 아이템 드롭 시그널을 발생시킨다.
extends StaticBody2D

signal brick_destroyed(position: Vector2, hp: int)

const TEXTURES := {
	1: preload("res://assets/images/bricks/tileGreen_14.png"),
	2: preload("res://assets/images/bricks/tileOrange_14.png"),
	3: preload("res://assets/images/bricks/tileRed_14.png"),
	-1: preload("res://assets/images/bricks/tileGrey_14.png"),
}

var hp: int = 1
var max_hp: int = 1
var is_indestructible: bool = false

@onready var sprite: Sprite2D = $Sprite2D


# 벽돌의 HP와 텍스처를 초기화한다.
func setup(brick_hp: int) -> void:
	hp = brick_hp
	if hp == -1:
		is_indestructible = true
		max_hp = -1
	else:
		max_hp = hp
	_update_texture()


# 공에 맞았을 때 호출된다. HP를 감소시키고 파괴 여부를 판정한다.
func hit() -> void:
	if is_indestructible:
		return
	hp -= 1
	if hp <= 0:
		brick_destroyed.emit(global_position, max_hp)
		queue_free()
	else:
		_update_texture()
		_play_hit_effect()


# HP에 맞는 텍스처로 교체한다.
func _update_texture() -> void:
	if sprite and TEXTURES.has(hp):
		sprite.texture = TEXTURES[hp]


# 피격 시 흰색 플래시 효과를 재생한다.
func _play_hit_effect() -> void:
	var tween := create_tween()
	sprite.modulate = Color.WHITE * 2.0
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
