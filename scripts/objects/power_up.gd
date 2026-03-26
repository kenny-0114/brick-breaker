# scripts/objects/power_up.gd
# 벽돌 파괴 시 드롭되는 파워업 아이템.
# 중력으로 낙하하며 패들에 닿으면 효과를 발동한다.
extends Area2D

enum Type { EXPAND, MULTI_BALL }

signal collected(type: Type)

const FALL_SPEED := 150.0
const TINT_EXPAND := Color(0.3, 0.9, 0.3)
const TINT_MULTI := Color(0.3, 0.6, 1.0)

var type: Type = Type.EXPAND

@onready var sprite: Sprite2D = $Sprite2D


# 파워업 타입을 설정하고 시각적 구분을 적용한다.
func setup(powerup_type: Type) -> void:
	type = powerup_type
	if sprite:
		match type:
			Type.EXPAND:
				sprite.modulate = TINT_EXPAND
			Type.MULTI_BALL:
				sprite.modulate = TINT_MULTI


func _physics_process(delta: float) -> void:
	position.y += FALL_SPEED * delta


# 패들과 접촉 시 수집 처리한다.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("paddle"):
		collected.emit(type)
		SoundManager.play_sfx(SoundManager.sfx_tap)
		queue_free()


# 화면 밖으로 나가면 제거한다.
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
