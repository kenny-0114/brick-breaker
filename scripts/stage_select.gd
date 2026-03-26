# scripts/stage_select.gd
# 스테이지 선택 화면. 해금 상태와 별을 표시하고 선택 시 게임을 시작한다.
extends Control

const TOTAL_LEVELS := 5

var star_tex := preload("res://assets/images/ui/star.png")
var star_outline_tex := preload("res://assets/images/ui/star_outline.png")
var _font := preload("res://assets/fonts/Kenney Future.ttf")

@onready var stage_grid: GridContainer = $VBoxContainer/StageGrid


func _ready() -> void:
	_build_stage_buttons()


# 스테이지 버튼을 동적으로 생성한다.
func _build_stage_buttons() -> void:
	var unlocked: int = SaveManager.data["unlocked_level"]
	var stars_data: Dictionary = SaveManager.data.get("stars", {})
	var high_scores: Dictionary = SaveManager.data.get("high_scores", {})

	for i in TOTAL_LEVELS:
		var level := i + 1
		var is_unlocked := level <= unlocked
		var btn := _create_stage_button(level, is_unlocked, stars_data, high_scores)
		stage_grid.add_child(btn)


# 개별 스테이지 버튼을 생성한다.
func _create_stage_button(level: int, is_unlocked: bool, stars_data: Dictionary, high_scores: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = Vector2(90, 100)

	# 버튼 스타일
	var style_unlocked := StyleBoxFlat.new()
	style_unlocked.bg_color = Color(0.31, 0.66, 0.87, 1)
	style_unlocked.set_corner_radius_all(12)
	style_unlocked.shadow_color = Color(0.17, 0.38, 0.5, 1)
	style_unlocked.shadow_size = 3
	style_unlocked.shadow_offset = Vector2(0, 3)

	var style_locked := StyleBoxFlat.new()
	style_locked.bg_color = Color(0.17, 0.17, 0.29, 1)
	style_locked.set_corner_radius_all(12)
	style_locked.border_color = Color(0.2, 0.2, 0.3, 1)
	style_locked.set_border_width_all(2)

	# 버튼
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 70)
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
	if is_unlocked:
		btn.text = str(level)
		btn.add_theme_stylebox_override("normal", style_unlocked)
		btn.add_theme_stylebox_override("hover", style_unlocked)
		btn.add_theme_stylebox_override("pressed", style_unlocked)
		btn.pressed.connect(_on_stage_selected.bind(level))
	else:
		btn.text = "🔒"
		btn.disabled = true
		btn.add_theme_stylebox_override("normal", style_locked)
		btn.add_theme_stylebox_override("disabled", style_locked)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.5, 1))
	container.add_child(btn)

	# 별 표시
	var stars_hbox := HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var earned_stars: int = stars_data.get(str(level), 0)
	for j in 3:
		var tex_rect := TextureRect.new()
		tex_rect.texture = star_tex if j < earned_stars else star_outline_tex
		tex_rect.custom_minimum_size = Vector2(20, 20)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_hbox.add_child(tex_rect)
	container.add_child(stars_hbox)

	return container


func _on_stage_selected(level: int) -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	GameManager.current_level = level
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")


func _on_back_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
