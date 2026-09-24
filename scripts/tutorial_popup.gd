# scripts/tutorial_popup.gd
# 기믹 첫 등장 시 표시되는 튜토리얼 팝업. 큐 방식으로 여러 개를 순차 표시한다.
extends CanvasLayer

signal all_tutorials_finished

# 기믹별 튜토리얼 데이터 (키, 제목, 설명, 아이콘 경로)
const TUTORIAL_DATA := {
	"tri": {
		"title": "Triangle Brick",
		"desc": "Balls bounce off the angled\nsurface. Aim carefully!",
		"icon": "res://assets/images/bricks/tri_brick_icon.png",
	},
	"missile": {
		"title": "Missile Item",
		"desc": "Destroy this brick to launch\nmissiles at nearby bricks!",
		"icon": "res://assets/images/items/missile/spaceMissiles_007.png",
	},
	"laser_shooter": {
		"title": "Laser Shooter",
		"desc": "Hit with a ball to fire lasers.\nLimited uses per stage!",
		"icon": "res://assets/images/items/missile/laser_shooter_1dir.png",
	},
	"ball_item": {
		"title": "Ball Item",
		"desc": "Collect with a ball to get\nan extra ball next turn!",
		"icon": "res://assets/images/ball/ball_blue_large.png",
	},
}

var _queue: Array[String] = []

@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Root/CenterBox/HeaderPanel/TitleLabel
@onready var desc_label: Label = $Root/CenterBox/BodyPanel/VBox/DescLabel
@onready var icon_rect: TextureRect = $Root/CenterBox/BodyPanel/VBox/IconRect
@onready var ok_btn: Button = $Root/CenterBox/ButtonRow/OkBtn


func _ready() -> void:
	ok_btn.pressed.connect(_on_ok_pressed)
	visible = false


# 표시할 튜토리얼 목록을 받아 큐에 넣고 첫 번째를 표시한다.
func show_tutorials(keys: Array[String]) -> void:
	_queue = keys.duplicate()
	if _queue.is_empty():
		all_tutorials_finished.emit()
		return
	_show_next()


# 큐에서 다음 튜토리얼을 꺼내 표시한다.
func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		all_tutorials_finished.emit()
		return

	var key: String = _queue[0]
	var info: Dictionary = TUTORIAL_DATA.get(key, {})
	if info.is_empty():
		push_warning("TutorialPopup: 알 수 없는 튜토리얼 키: %s" % key)
		_queue.pop_front()
		_show_next()
		return

	title_label.text = info["title"]
	desc_label.text = info["desc"]

	# 아이콘 로드
	var tex: Texture2D = load(info["icon"]) as Texture2D
	if tex:
		icon_rect.texture = tex
		icon_rect.visible = true
	else:
		icon_rect.visible = false

	visible = true


# OK 버튼 클릭 시 현재 튜토리얼을 본 것으로 저장하고 다음으로 진행한다.
func _on_ok_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	if not _queue.is_empty():
		var key: String = _queue.pop_front()
		SaveManager.mark_tutorial_seen(key)
	_show_next()
