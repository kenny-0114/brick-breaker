# scripts/first_shot_tutorial.gd
# 첫 발사 인게임 오버레이. 터치 포인터 드래그 애니메이션으로 조작법을 안내한다.
# 화면 터치 시 fade out되며 실제 조준이 시작된다.
extends CanvasLayer

signal tutorial_dismissed(touch_position: Vector2)

const DRAG_START := Vector2(240, 700)
const DRAG_END := Vector2(300, 400)

var _drag_tween: Tween = null
var _is_active := false

@onready var dimmer: ColorRect = $Dimmer
@onready var pointer: Sprite2D = $Pointer
@onready var hint_label: Label = $HintLabel


func _ready() -> void:
	visible = false


# 튜토리얼 오버레이를 표시하고 드래그 애니메이션을 시작한다.
func show_tutorial() -> void:
	_is_active = true
	visible = true
	dimmer.modulate.a = 1.0
	pointer.modulate.a = 1.0
	hint_label.modulate.a = 1.0
	pointer.position = DRAG_START
	_start_drag_animation()


# 드래그 반복 애니메이션을 재생한다.
func _start_drag_animation() -> void:
	if _drag_tween and _drag_tween.is_valid():
		_drag_tween.kill()

	pointer.position = DRAG_START
	_drag_tween = create_tween()
	_drag_tween.set_loops()

	# 잠시 대기 → 위로 드래그 → 잠시 대기 → 원위치로 리셋
	_drag_tween.tween_interval(0.5)
	_drag_tween.tween_property(pointer, "position", DRAG_END, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_drag_tween.tween_interval(0.4)
	_drag_tween.tween_property(pointer, "position", DRAG_START, 0.0)


# 화면 터치/클릭 시 오버레이를 닫는다.
func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	var is_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT
	if is_touch or is_click:
		get_viewport().set_input_as_handled()
		_dismiss(event.position)


# 누른 위치를 즉시 전달해 조준을 시작하고 오버레이만 fade out한다.
func _dismiss(touch_position: Vector2) -> void:
	_is_active = false
	if _drag_tween and _drag_tween.is_valid():
		_drag_tween.kill()
	tutorial_dismissed.emit(touch_position)

	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(dimmer, "modulate:a", 0.0, 0.3)
	fade.tween_property(pointer, "modulate:a", 0.0, 0.3)
	fade.tween_property(hint_label, "modulate:a", 0.0, 0.3)
	await fade.finished

	visible = false
