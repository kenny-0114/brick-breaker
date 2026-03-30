# scripts/objects/laser_beam.gd
# 레이저 빔 연출. 지정 방향으로 빔을 표시하고 경로상 벽돌에 데미지를 적용한다.
extends Node2D

const FLASH_DURATION := 0.1
const FADE_DURATION := 0.1

var _damage: int = 1

@onready var beam_sprite: Sprite2D = $BeamSprite


# 빔을 초기화한다. 방향, 길이, 데미지를 설정하고 즉시 데미지를 적용한다.
func setup(direction: int, beam_length: float, damage: int, bricks_in_path: Array) -> void:
	_damage = damage

	# 방향에 따라 회전 (0=위, 1=오른쪽, 2=아래, 3=왼쪽)
	rotation_degrees = direction * 90.0

	# 빔 길이 설정 (laser.png는 세로 256px, y스케일로 길이 조절)
	var tex_height: float = beam_sprite.texture.get_size().y
	beam_sprite.scale.y = beam_length / tex_height
	# 빔을 슈터에서 바깥쪽으로 배치 (피벗이 하단이 되도록)
	beam_sprite.position.y = -beam_length / 2.0

	# 경로상 벽돌에 데미지 적용
	for brick in bricks_in_path:
		if is_instance_valid(brick) and not brick._is_destroyed:
			for i in range(_damage):
				brick.hit()

	# 번쩍 + 페이드아웃 연출
	_play_flash()


# 번쩍 효과 후 페이드아웃하여 소멸한다.
func _play_flash() -> void:
	beam_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(beam_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), FLASH_DURATION)
	tween.tween_property(beam_sprite, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
