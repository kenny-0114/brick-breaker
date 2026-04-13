# scripts/stage_preview_popup.gd
# 스테이지 미리보기 팝업. SubViewport에 레벨을 로드하여 축소 표시한다.
extends CanvasLayer

signal start_pressed(level: int)
signal cancel_pressed

const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_ITEM_SCENE := preload("res://scenes/objects/ball_item.tscn")
const LASER_SHOOTER_SCENE := preload("res://scenes/objects/laser_shooter.tscn")
const GRID_COLS := 10
const INITIAL_BOTTOM_ROW := 6
const PREVIEW_TOP_OFFSET := 10.0

var _selected_level: int = 0

@onready var sub_viewport: SubViewport = $SubViewport
@onready var preview_rect: TextureRect = $Root/CenterBox/BodyPanel/PreviewRect
@onready var title_label: Label = $Root/CenterBox/HeaderPanel/TitleLabel
@onready var start_btn: Button = $Root/CenterBox/ButtonRow/StartBtn
@onready var cancel_btn: Button = $Root/CenterBox/ButtonRow/CancelBtn
@onready var brick_container: Node2D = $SubViewport/BrickContainer
@onready var item_container: Node2D = $SubViewport/ItemContainer
@onready var shooter_container: Node2D = $SubViewport/ShooterContainer
@onready var dimmer: ColorRect = $Dimmer


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	preview_rect.texture = sub_viewport.get_texture()
	visible = false


# 미리보기 팝업을 표시한다. 레벨 데이터를 로드하여 SubViewport에 렌더링한다.
func show_preview(level: int) -> void:
	_selected_level = level
	title_label.text = "STAGE %d" % level
	_clear_containers()
	_load_preview(level)
	visible = true
	# SubViewport 렌더링을 위해 한 프레임 대기 후 갱신
	await get_tree().process_frame
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# 미리보기 팝업을 닫는다.
func hide_preview() -> void:
	visible = false
	_clear_containers()


# 모든 컨테이너의 자식 노드를 제거한다.
func _clear_containers() -> void:
	for child in brick_container.get_children():
		child.queue_free()
	for child in item_container.get_children():
		child.queue_free()
	for child in shooter_container.get_children():
		child.queue_free()


# 레벨 JSON을 읽어 벽돌/아이템/슈터를 SubViewport에 배치한다. HP 라벨은 숨긴다.
func _load_preview(level: int) -> void:
	var path := "res://data/levels/level_%d.json" % level
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("StagePreviewPopup: 레벨 파일을 찾을 수 없습니다: %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("StagePreviewPopup: JSON 파싱 실패: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data

	# 셀 크기 계산 (SubViewport 너비 기준)
	var viewport_width: float = sub_viewport.size.x
	var cell_width: float = viewport_width / GRID_COLS
	var cell_height: float = cell_width
	var cell_size := Vector2(cell_width, cell_height)

	# 배치 데이터 파싱
	var bricks_array: Array = data.get("bricks", []) as Array
	var items_array: Array = data.get("ball_items", []) as Array
	var shooters_array: Array = data.get("laser_shooters", []) as Array

	# 최하단 row 기준 오프셋 계산 (게임과 동일한 로직)
	var max_row := 0
	for brick_d: Dictionary in bricks_array:
		max_row = maxi(max_row, int(brick_d["row"]))
	for item_d: Dictionary in items_array:
		max_row = maxi(max_row, int(item_d["row"]))
	for shooter_d: Dictionary in shooters_array:
		max_row = maxi(max_row, int(shooter_d["row"]))
	var row_offset: int = maxi(0, max_row - INITIAL_BOTTOM_ROW)

	# 벽돌 배치 (HP 라벨 숨김)
	for brick_data: Dictionary in bricks_array:
		var brick: StaticBody2D = BRICK_SCENE.instantiate()
		var row: int = int(brick_data["row"])
		var col: int = int(brick_data["col"])
		var hp: int = int(brick_data["hp"])
		var brick_type: String = str(brick_data.get("type", "rect"))
		brick.position = Vector2(
			(col + 0.5) * cell_width,
			PREVIEW_TOP_OFFSET + (row - row_offset + 0.5) * cell_height
		)
		var item_type: String = str(brick_data.get("item", ""))
		brick.item = item_type
		brick_container.add_child(brick)
		if brick_type == "tri":
			var dir: int = int(brick_data.get("dir", 0))
			brick.setup_triangle(hp, dir, cell_size, false)
		else:
			var tex_size: Vector2 = brick.sprite.texture.get_size()
			brick.sprite.scale = Vector2(cell_width / tex_size.x, cell_height / tex_size.y)
			var col_shape: CollisionShape2D = brick.get_node("CollisionShape2D")
			col_shape.shape = col_shape.shape.duplicate()
			col_shape.shape.size = Vector2(cell_width, cell_height)
			brick.setup(hp, cell_size, false)

	# 공 아이템 배치
	for item_data: Dictionary in items_array:
		var item: Area2D = BALL_ITEM_SCENE.instantiate()
		var row: int = int(item_data["row"])
		var col: int = int(item_data["col"])
		item.position = Vector2(
			(col + 0.5) * cell_width,
			PREVIEW_TOP_OFFSET + (row - row_offset + 0.5) * cell_height
		)
		item_container.add_child(item)

	# 레이저 슈터 배치
	for shooter_data: Dictionary in shooters_array:
		var shooter: Area2D = LASER_SHOOTER_SCENE.instantiate()
		var row: int = int(shooter_data["row"])
		var col: int = int(shooter_data["col"])
		var shooter_uses: int = int(shooter_data.get("uses", 10))
		var shooter_damage: int = int(shooter_data.get("damage", 1))
		var shooter_dirs: Array = shooter_data.get("dirs", [0]) as Array
		shooter.position = Vector2(
			(col + 0.5) * cell_width,
			PREVIEW_TOP_OFFSET + (row - row_offset + 0.5) * cell_height
		)
		shooter_container.add_child(shooter)
		shooter.setup(shooter_uses, shooter_damage, shooter_dirs, cell_size, brick_container)
		# 미리보기에서는 히트수 라벨을 숨긴다
		shooter.uses_label.visible = false


func _on_start_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	start_pressed.emit(_selected_level)


func _on_cancel_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	hide_preview()
	cancel_pressed.emit()
