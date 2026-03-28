# scripts/game_over_menu.gd
# 게임오버/스테이지 클리어 결과 화면. 별이 순차적으로 파티클과 함께 등장한다.
extends CanvasLayer

const STAR_FILLED := preload("res://assets/images/ui/star.png")
const STAR_EMPTY := preload("res://assets/images/ui/star_grey.png")
const BTN_BLUE := preload("res://assets/images/ui/btn_blue.png")
const BTN_RED := preload("res://assets/images/ui/btn_red.png")

const STAR_DELAY := 0.4
const STAR_ANIM_DURATION := 0.25
const SFX_STAR := preload("res://assets/sounds/sfx_result_star.ogg")

@onready var dimmer: ColorRect = $Dimmer
@onready var root: Control = $Root
@onready var title_label: Label = $Root/CenterBox/HeaderMargin/HeaderPanel/TitleLabel
@onready var score_label: Label = $Root/CenterBox/BodyPanel/VBox/ScoreLabel
@onready var star_left: TextureRect = $Root/CenterBox/MarginContainer/StarsRow/StarLeft
@onready var star_center: TextureRect = $Root/CenterBox/MarginContainer/StarsRow/StarCenter
@onready var star_right: TextureRect = $Root/CenterBox/MarginContainer/StarsRow/StarRight
@onready var header_panel: Panel = $Root/CenterBox/HeaderMargin/HeaderPanel
@onready var next_btn: TextureButton = $Root/CenterBox/ButtonRow/NextBtn
@onready var retry_btn: TextureButton = $Root/CenterBox/ButtonRow/RetryBtn


func _ready() -> void:
	dimmer.visible = false
	root.visible = false


# 게임오버 화면을 표시한다.
func show_game_over() -> void:
	title_label.text = "GAME OVER"
	_set_header_texture(BTN_RED)
	score_label.text = str(GameManager.score)
	next_btn.visible = false
	retry_btn.custom_minimum_size = Vector2(70, 70)
	_show()
	_animate_stars(0)


# 스테이지 클리어 화면을 표시한다.
func show_clear() -> void:
	title_label.text = "STAGE CLEAR!"
	_set_header_texture(BTN_BLUE)
	score_label.text = str(GameManager.score)
	var stars := GameManager.calculate_stars()
	next_btn.visible = true
	retry_btn.custom_minimum_size = Vector2(56, 56)
	_show()
	_animate_stars(stars)


# 별 연출: 회색 별 3개 → 획득한 별만 순차적으로 채워짐 + 파티클
func _animate_stars(count: int) -> void:
	var star_nodes := [star_left, star_center, star_right]

	# 먼저 3개 모두 회색 별로 표시
	for star in star_nodes:
		star.texture = STAR_EMPTY
		star.modulate = Color.WHITE
		star.scale = Vector2.ONE
		star.pivot_offset = star.size * 0.5

	# 획득한 별만 순차적으로 채움 연출
	for i in count:
		var timer := get_tree().create_timer(STAR_DELAY * (i + 1))
		await timer.timeout

		var star: TextureRect = star_nodes[i]

		# 스케일 펀치: 커졌다 원래로
		star.scale = Vector2(1.4, 1.4)
		star.texture = STAR_FILLED
		var tween := create_tween()
		tween.tween_property(star, "scale", Vector2.ONE, STAR_ANIM_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

		# 효과음 + 파티클 발사
		SoundManager.play_sfx(SFX_STAR)
		_spawn_star_particles(star)


# 별 위치에서 반짝이 파티클을 발사한다.
func _spawn_star_particles(star: TextureRect) -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.6
	# 별의 중앙 위치 계산
	particles.position = star.global_position + star.size * 0.5

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 200, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.angular_velocity_min = -300.0
	mat.angular_velocity_max = 300.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 15.0
	mat.color = Color(1.0, 0.85, 0.2, 1.0)

	particles.process_material = mat
	particles.texture = STAR_FILLED

	# Root에 추가 (CanvasLayer 직계)
	add_child(particles)
	particles.finished.connect(particles.queue_free)


# 헤더 패널의 StyleBoxTexture를 변경한다.
func _set_header_texture(tex: Texture2D) -> void:
	var style := header_panel.get_theme_stylebox("panel").duplicate() as StyleBoxTexture
	style.texture = tex
	header_panel.add_theme_stylebox_override("panel", style)


# 화면을 표시한다.
func _show() -> void:
	dimmer.visible = true
	root.visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_next_pressed() -> void:
	get_tree().paused = false
	GameManager.current_level += 1
	get_tree().reload_current_scene()
