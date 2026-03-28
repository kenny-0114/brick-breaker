# scripts/stage_select.gd
# 스테이지 선택 화면. 해금 상태와 별을 표시하고 선택 시 게임을 시작한다.
extends Control

const TOTAL_LEVELS := 5

var star_tex := preload("res://assets/images/ui/star.png")
var star_outline_tex := preload("res://assets/images/ui/star_grey.png")
var _font := preload("res://assets/fonts/Kenney Future.ttf")

@onready var stage_grid: GridContainer = $VBoxContainer/StageGrid


func _ready() -> void:
	_build_stage_buttons()


# 스테이지 버튼을 동적으로 생성한다.
func _build_stage_buttons() -> void:
	var unlocked: int = int(SaveManager.data["unlocked_level"])
	var stars_data: Dictionary = SaveManager.data.get("stars", {}) as Dictionary
	var _scores: Dictionary = SaveManager.data.get("high_scores", {}) as Dictionary

	for i in TOTAL_LEVELS:
		var level := i + 1
		var is_unlocked := level <= unlocked
		var btn := _create_stage_button(level, is_unlocked, stars_data)
		stage_grid.add_child(btn)


# 개별 스테이지 버튼을 생성한다. Kenney UI NinePatch 카드로 배치된다.
func _create_stage_button(level: int, is_unlocked: bool, stars_data: Dictionary) -> Control:
	# Kenney NinePatch 텍스처 버튼 스타일
	var tex_green := preload("res://assets/images/ui/btn_green.png")
	var tex_grey := preload("res://assets/images/ui/btn_grey.png")
	var tex_yellow := preload("res://assets/images/ui/btn_yellow.png")

	var style_unlocked := StyleBoxTexture.new()
	style_unlocked.texture = tex_green
	style_unlocked.texture_margin_left = 12.0
	style_unlocked.texture_margin_top = 12.0
	style_unlocked.texture_margin_right = 12.0
	style_unlocked.texture_margin_bottom = 16.0

	var style_locked := StyleBoxTexture.new()
	style_locked.texture = tex_grey
	style_locked.texture_margin_left = 12.0
	style_locked.texture_margin_top = 12.0
	style_locked.texture_margin_right = 12.0
	style_locked.texture_margin_bottom = 16.0
	style_locked.modulate_color = Color(1, 1, 1, 0.4)

	# 버튼 — 정사각형 고정 크기, 내부 컨텐츠를 직접 배치
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(88, 88)
	# 버튼 텍스트 비우고 내부에 레이아웃 배치
	btn.text = ""
	if is_unlocked:
		btn.add_theme_stylebox_override("normal", style_unlocked)
		btn.add_theme_stylebox_override("hover", style_unlocked)
		btn.add_theme_stylebox_override("pressed", style_unlocked)
		btn.pressed.connect(_on_stage_selected.bind(level))
	else:
		btn.disabled = true
		btn.add_theme_stylebox_override("normal", style_locked)
		btn.add_theme_stylebox_override("disabled", style_locked)

	# 버튼 내부 레이아웃 (숫자 + 별) — 버튼 영역 안에 패딩 적용
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 2)

	# 숫자 라벨
	var num_label := Label.new()
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.add_theme_font_override("font", _font)
	num_label.add_theme_font_size_override("font_size", 24)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_unlocked:
		num_label.text = str(level)
		num_label.add_theme_color_override("font_color", Color.WHITE)
		num_label.add_theme_color_override("font_outline_color", Color(0.15, 0.4, 0.18, 1))
		num_label.add_theme_constant_override("outline_size", 3)
	else:
		num_label.text = "🔒"
		num_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.5))
	inner.add_child(num_label)

	# 별 표시 — 고정 크기 14x14, expand_mode로 축소 강제
	var stars_hbox := HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_hbox.add_theme_constant_override("separation", 2)
	var earned_stars: int = int(stars_data.get(str(level), 0))
	for j in 3:
		var tex_rect := TextureRect.new()
		tex_rect.texture = star_tex if j < earned_stars else star_outline_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(14, 14)
		tex_rect.size = Vector2(14, 14)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_hbox.add_child(tex_rect)
	inner.add_child(stars_hbox)

	margin.add_child(inner)
	btn.add_child(margin)
	return btn


func _on_stage_selected(level: int) -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	GameManager.current_level = level
	get_tree().change_scene_to_file("res://scenes/turn_game_scene.tscn")


func _on_back_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
