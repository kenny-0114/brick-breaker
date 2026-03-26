# scripts/objects/paddle.gd
# 터치/드래그로 X축 이동하는 패들.
# 공의 패들 타격 위치에 따라 반사각을 조정한다.
extends AnimatableBody2D


const EXPAND_SCALE := 1.5
const EXPAND_DURATION := 10.0

var _screen_width: float
var _half_width: float
var _is_expanded := false
var _expand_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_screen_width = get_viewport_rect().size.x
	_update_half_width()


func _input(event: InputEvent) -> void:
	# 터치/마우스 드래그로 패들을 X축으로 이동시킨다.
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		var target_x: float = event.position.x
		target_x = clampf(target_x, _half_width, _screen_width - _half_width)
		position.x = target_x


# 공이 패들의 어느 위치를 맞았는지 -1.0~1.0으로 반환한다.
# -1.0은 왼쪽 끝, 0.0은 중앙, 1.0은 오른쪽 끝이다.
func get_hit_factor(ball_x: float) -> float:
	var diff := ball_x - global_position.x
	return clampf(diff / _half_width, -1.0, 1.0)


# 패들 확장 파워업을 적용한다.
func expand() -> void:
	# 이미 확장 중이면 타이머만 리셋한다.
	if _expand_tween and _expand_tween.is_running():
		_expand_tween.kill()
	if not _is_expanded:
		_is_expanded = true
		scale.x = EXPAND_SCALE
		_update_half_width()
	# 지속 시간 후 원복
	_expand_tween = create_tween()
	_expand_tween.tween_interval(EXPAND_DURATION)
	_expand_tween.tween_property(self, "scale:x", 1.0, 0.3)
	_expand_tween.tween_callback(_on_expand_ended)


func _on_expand_ended() -> void:
	_is_expanded = false
	_update_half_width()


# 패들의 실제 반폭을 갱신한다.
func _update_half_width() -> void:
	if collision and collision.shape:
		_half_width = collision.shape.size.x * 0.5 * scale.x
