# scripts/objects/missile.gd
# 미사일 비행 노드. 타겟까지 직선 비행 후 폭발 이펙트를 재생하고 소멸한다.
extends Node2D

const CROSSHAIR_TEXTURE := preload("res://kenney-res/crosshair_red_large.png")
const EXPLOSION_TEXTURES := [
	preload("res://kenney-res/explosion1.png"),
	preload("res://kenney-res/explosion2.png"),
	preload("res://kenney-res/explosion3.png"),
]
const SMOKE_TEXTURE := preload("res://kenney_space-shooter-extension/PNG/Sprites/Effects/spaceEffects_009.png")
const FLIGHT_DURATION := 0.35
const SMOKE_LIFETIME := 0.3

var _target_brick: Node = null
var _target_pos: Vector2 = Vector2.ZERO

@onready var missile_sprite: Sprite2D = $MissileSprite
@onready var smoke_particles: GPUParticles2D = $SmokeParticles


# 미사일을 초기화한다. 타겟 벽돌과 위치를 설정한다.
func setup(target_brick: Node, target_position: Vector2) -> void:
	_target_brick = target_brick
	_target_pos = target_position


# 타겟 방향으로 회전하고 비행을 시작한다.
func launch() -> void:
	# 타겟 방향으로 회전
	var angle: float = global_position.angle_to_point(_target_pos)
	missile_sprite.rotation = angle + PI / 2.0

	# 연기 파티클 시작
	smoke_particles.emitting = true

	# Tween으로 직선 비행
	var tween := create_tween()
	tween.tween_property(self, "global_position", _target_pos, FLIGHT_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_arrived)


# 미사일이 타겟에 도착했을 때 호출된다.
func _on_arrived() -> void:
	# 연기 중지
	smoke_particles.emitting = false

	# 미사일 스프라이트 숨기기
	missile_sprite.visible = false

	# 타겟 벽돌이 아직 유효하면 즉시 파괴
	if is_instance_valid(_target_brick) and not _target_brick.is_queued_for_deletion():
		_target_brick.destroy_by_missile()

	# 폭발 이펙트 재생
	_play_explosion()


# 폭발 이펙트를 재생한다. explosion1~3을 순차 표시 후 자동 소멸한다.
func _play_explosion() -> void:
	var explosion_sprite := Sprite2D.new()
	explosion_sprite.scale = Vector2(0.8, 0.8)
	add_child(explosion_sprite)

	var tween := create_tween()
	for i in range(EXPLOSION_TEXTURES.size()):
		tween.tween_callback(func(): explosion_sprite.texture = EXPLOSION_TEXTURES[i])
		tween.tween_interval(0.08)

	# 마지막 프레임 후 페이드아웃 + 소멸
	tween.tween_property(explosion_sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
