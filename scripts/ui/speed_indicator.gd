# scripts/ui/speed_indicator.gd
# 배속 변경 시 화면 중앙에 [>>] x2 형태로 표시하는 인디케이터.
# 페이드인으로 등장하고, 배속 해제 시 페이드아웃한다.
extends CanvasLayer

const FADE_IN_DURATION := 0.2
const FADE_OUT_DURATION := 0.3

var _tween: Tween = null

@onready var hbox: HBoxContainer = $HBox
@onready var icon: TextureRect = $HBox/Icon
@onready var label: Label = $HBox/SpeedLabel


func _ready() -> void:
	hbox.modulate.a = 0.0
	hbox.visible = false


# 배속이 변경되었을 때 호출한다. 1.0 이하면 숨긴다.
func show_speed(scale: float) -> void:
	if scale <= 1.0:
		_hide_indicator()
		return
	label.text = "x%d" % int(scale)
	_show_indicator()


# 페이드인하며 인디케이터를 표시한다.
func _show_indicator() -> void:
	hbox.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hbox, "modulate:a", 1.0, FADE_IN_DURATION)


# 페이드아웃하며 인디케이터를 숨긴다.
func _hide_indicator() -> void:
	if hbox.modulate.a <= 0.0:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hbox, "modulate:a", 0.0, FADE_OUT_DURATION)
	_tween.tween_callback(func(): hbox.visible = false)
