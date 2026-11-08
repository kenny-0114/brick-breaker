# tests/p0_runner.gd
# P0 자동 검사 실행기. tools/run_p0.py가 케이스마다 별도 Godot 프로세스로 실행한다.
# 실행 예: godot --headless --path . --script res://tests/p0_runner.gd -- --save-path=user://p0/<uuid>.json --case=turn
# 출력 계약: stdout에 `P0_RESULT {json}` 한 줄. 종료 코드 0=PASS, 1=FAIL, 2=환경 오류.
# 검증 대상 동작은 실제 입력 이벤트로만 일으킨다(내부 함수 직접 호출 금지). 상태 읽기는 관찰 용도로만 한다.
extends SceneTree

const EXIT_PASS := 0
const EXIT_FAIL := 1
const EXIT_ENV := 2
const TURN_SCENE_PATH := "res://scenes/turn_game_scene.tscn"
const LEVEL_PATH_FORMAT := "res://data/levels/level_%d.json"
const SCENE_READY_MAX_FRAMES := 120
const TURN_MAX_FRAMES := 20000
const TURN_LEVEL := 1
# 한 턴 시나리오의 제스처: 안내를 닫는 누름 위치 → 비수직 경유점 → 해제 위치
# 경유점은 드래그 처리가 실제로 조준 방향을 바꾸는지 확인하기 위해 일부러 옆으로 비튼다.
const GESTURE_PRESS := Vector2(240, 690)
const GESTURE_DRAG_VIA := Vector2(100, 400)
const GESTURE_DRAG_END := Vector2(240, 100)  # 5·6열 사이 빈 통로로 수직 발사 (레벨 1이 한 턴에 클리어되지 않는 샷)
const NEXT_TURN_DRAG_END := Vector2(400, 300)  # 다음 턴 조준 확인용 (해제하지 않음)
const GESTURE_DRAG_STEPS := 8
const AIM_TOLERANCE_RAD := 0.05
const BALL_SCENE_PATH := "res://scenes/objects/ball.tscn"
const MIN_HORIZONTAL_DEG := 5.0  # 공이 벽에 튄 뒤 수평에서 최소 이만큼은 기울어야 한다(조준 한계 85°와 같음)
const NEAR_HORIZONTAL_DIR := Vector2(1.0, 0.004)  # 약 0.2° — 실제로 회수되지 않던 공의 각도
const BOUNCE_MAX_FRAMES := 180
const AIM_LIMIT_FROM_UP_DEG := 85.0  # launcher.gd MAX_AIM_ANGLE(170°)의 절반
const AIM_OVER_LIMIT_RIGHT := Vector2(470, 700)  # 발사점(240,708) 기준 오른쪽, 한계를 넘는 거의 수평 드래그
const AIM_OVER_LIMIT_LEFT := Vector2(10, 700)
const STATE_AIMING := 0  # turn_game_scene.gd의 State.AIMING

var _case := ""
var _level := 0
var _save_path := ""
var _is_self_test_fail := false
var _checks: Array[Dictionary] = []
# --script 모드에서는 autoload 이름이 컴파일 시점에 없으므로 노드로 참조한다.
var _gm: Node = null
var _sm: Node = null


# 진입점. 인자를 파싱하고 케이스를 비동기로 실행한다.
func _initialize() -> void:
	_run.call_deferred()


# 케이스 실행의 전체 흐름. 환경 확인 → 케이스 실행 → 결과 출력 → 종료.
func _run() -> void:
	var env_error := _parse_args()
	if env_error == "":
		env_error = _verify_save_isolation()
	if env_error != "":
		_finish_env_error(env_error)
		return
	match _case:
		"title":
			await _case_title()
		"load":
			await _case_load(_level)
		"turn":
			await _case_turn()
		"ball_angle":
			await _case_ball_angle()
		"aim_clamp":
			await _case_aim_clamp()
		_:
			_finish_env_error("알 수 없는 케이스: %s" % _case)
			return
	_finish()


# 명령행 인자를 읽는다. 문제가 있으면 오류 메시지를, 정상이면 빈 문자열을 돌려준다.
func _parse_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--level="):
			_level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--save-path="):
			_save_path = arg.trim_prefix("--save-path=")
		elif arg == "--self-test=fail":
			_is_self_test_fail = true
	if _case == "":
		return "--case 인자가 없습니다"
	if _save_path == "":
		return "--save-path 인자가 없습니다 (실제 저장 보호를 위해 필수)"
	if _case == "load" and (_level < 1 or not FileAccess.file_exists(LEVEL_PATH_FORMAT % _level)):
		return "--level 값이 잘못되었거나 레벨 파일이 없습니다: %d" % _level
	return ""


# SaveManager가 실제로 테스트 저장 경로를 쓰고 있는지 확인한다. 격리되지 않았다면 즉시 중단한다.
func _verify_save_isolation() -> String:
	_gm = root.get_node_or_null("GameManager")
	_sm = root.get_node_or_null("SaveManager")
	if _gm == null or _sm == null:
		return "GameManager/SaveManager autoload를 찾지 못했습니다"
	var active_path: Variant = _sm.get("_save_path")
	if active_path == null:
		return "SaveManager에 _save_path가 없습니다 (저장 경로 인자 미구현)"
	if str(active_path) != _save_path:
		return "저장 격리 실패: SaveManager 경로 %s ≠ 요청 경로 %s" % [active_path, _save_path]
	return ""


# 검사 항목 하나를 기록한다.
func _check(name: String, is_ok: bool, detail: Variant = "") -> void:
	_checks.append({"name": name, "ok": is_ok, "detail": str(detail)})


# 조건이 참이 될 때까지 프레임을 기다린다. 제한 프레임 안에 참이 되면 true.
func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


# 지정 프레임 수만큼 기다린다.
func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame


# 씬을 전환하고 지정 경로의 씬이 current_scene으로 준비될 때까지 기다린다.
func _change_scene_and_wait(scene_path: String) -> Node:
	var err := change_scene_to_file(scene_path)
	if err != OK:
		_check("씬 전환 요청 %s" % scene_path, false, error_string(err))
		return null
	var is_ready := await _wait_until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == scene_path and current_scene.is_node_ready()
	, SCENE_READY_MAX_FRAMES)
	_check("씬 준비 %s" % scene_path, is_ready)
	if not is_ready:
		return null
	# _ready 이후 deferred 처리(레벨 배치, 팝업 표시)가 끝나도록 몇 프레임 더 기다린다.
	await _wait_frames(3)
	return current_scene


# ── 케이스: 타이틀 기동 ──────────────────────────────────────────

# project.godot의 메인 씬을 실제로 로드해 준비되는지 확인한다.
func _case_title() -> void:
	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check("메인 씬 설정 존재", main_scene_path != "", main_scene_path)
	if main_scene_path == "":
		return
	var scene := await _change_scene_and_wait(main_scene_path)
	if scene == null:
		return
	_check("메인 씬이 타이틀 화면", main_scene_path.ends_with("title_screen.tscn"), main_scene_path)
	_check("타이틀 스크립트 연결", scene.get_script() != null and str(scene.get_script().resource_path).ends_with("title_screen.gd"))


# ── 케이스: 레벨 로드 ────────────────────────────────────────────

# 레벨 JSON에서 기대값을 직접 계산한다. 게임의 로더를 재사용하지 않는 독립 계산이다.
func _read_level_expectation(level: int) -> Dictionary:
	var file := FileAccess.open(LEVEL_PATH_FORMAT % level, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	var bricks: Array = data.get("bricks", [])
	var hps: Array[int] = []
	var tri_count := 0
	var missile_count := 0
	var destructible_count := 0
	for brick_d: Dictionary in bricks:
		var hp := int(brick_d["hp"])
		hps.append(hp)
		if str(brick_d.get("type", "rect")) == "tri":
			tri_count += 1
		if str(brick_d.get("item", "")) == "missile":
			missile_count += 1
		if hp != -1:
			destructible_count += 1
	hps.sort()
	return {
		"brick_count": bricks.size(),
		"brick_hps": hps,
		"tri_count": tri_count,
		"missile_count": missile_count,
		"destructible_count": destructible_count,
		"item_count": (data.get("ball_items", []) as Array).size(),
		"shooter_count": (data.get("laser_shooters", []) as Array).size(),
		"initial_balls": int(data.get("initial_balls", 1)),
		"ball_speed": float(data.get("ball_speed", 400.0)),
	}


# 실제 게임 씬에서 레벨을 로드하고 배치 결과를 JSON 기대값과 대조한다.
func _case_load(level: int) -> void:
	var expected := _read_level_expectation(level)
	_check("레벨 JSON 파싱(독립)", not expected.is_empty(), LEVEL_PATH_FORMAT % level)
	if expected.is_empty():
		return
	# 픽스처 준비: 스테이지 선택 화면이 하는 것과 같이 레벨 번호만 지정한다.
	_gm.current_level = level
	var scene := await _change_scene_and_wait(TURN_SCENE_PATH)
	if scene == null:
		return
	var bricks := scene.get_node("BrickContainer").get_children()
	var actual_hps: Array[int] = []
	var actual_tri := 0
	var actual_missile := 0
	for brick in bricks:
		actual_hps.append(int(brick.hp))
		if brick._is_triangle:
			actual_tri += 1
		if brick.item == "missile":
			actual_missile += 1
	actual_hps.sort()
	_check("벽돌 개수", bricks.size() == expected["brick_count"], "%d / 기대 %d" % [bricks.size(), expected["brick_count"]])
	_check("벽돌 HP 구성", actual_hps == expected["brick_hps"])
	_check("삼각형 벽돌 개수", actual_tri == expected["tri_count"], "%d / 기대 %d" % [actual_tri, expected["tri_count"]])
	_check("미사일 아이템 벽돌 개수", actual_missile == expected["missile_count"], "%d / 기대 %d" % [actual_missile, expected["missile_count"]])
	var item_count := scene.get_node("ItemContainer").get_child_count()
	_check("공 아이템 개수", item_count == expected["item_count"], "%d / 기대 %d" % [item_count, expected["item_count"]])
	var shooter_count := scene.get_node("ShooterContainer").get_child_count()
	_check("레이저 슈터 개수", shooter_count == expected["shooter_count"], "%d / 기대 %d" % [shooter_count, expected["shooter_count"]])
	_check("초기 공 수", _gm.ball_count == expected["initial_balls"], "%d / 기대 %d" % [_gm.ball_count, expected["initial_balls"]])
	var launcher_speed := float(scene.get_node("Launcher")._ball_speed)
	_check("공 속도", is_equal_approx(launcher_speed, expected["ball_speed"]), "%s / 기대 %s" % [launcher_speed, expected["ball_speed"]])
	_check("현재 레벨", _gm.current_level == level)
	_check("턴 0에서 시작", _gm.turn_count == 0, _gm.turn_count)


# ── 케이스: 레벨 1 터치 한 턴 ────────────────────────────────────

# 480×854 뷰포트 좌표를 창 좌표로 바꾼다.
# Input.parse_input_event는 창 좌표를 받는데, headless는 창 크기가 0이라 늘이기 변환이 1배가 아니다.
func _to_window(viewport_position: Vector2) -> Vector2:
	return root.get_final_transform() * viewport_position


# 터치 이벤트 하나를 실제 입력 경로로 주입한다. 좌표는 뷰포트 기준이다.
func _send_touch(position: Vector2, is_pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = _to_window(position)
	event.pressed = is_pressed
	Input.parse_input_event(event)


# 드래그 이벤트 하나를 실제 입력 경로로 주입한다. 좌표는 뷰포트 기준이다.
func _send_drag(position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _to_window(position)
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)


# 누른 상태에서 from → to로 여러 단계에 걸쳐 드래그한다.
func _drag_path(from: Vector2, to: Vector2, steps: int) -> void:
	var previous := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		_send_drag(point, point - previous)
		previous = point
		await process_frame


# 신규 저장에서 첫 발사 안내 → 같은 제스처로 조준 → 해제 → 공 회수 → 다음 조준까지 검증한다.
func _case_turn() -> void:
	_gm.current_level = TURN_LEVEL
	var scene := await _change_scene_and_wait(TURN_SCENE_PATH)
	if scene == null:
		return
	var launcher: Node = scene.get_node("Launcher")
	var tutorial: CanvasLayer = scene.get_node("FirstShotTutorial")
	var ball_container: Node = scene.get_node("BallContainer")
	var floor_zone: Area2D = scene.get_node("Floor")

	# 관찰용 기록. 게임 흐름에는 개입하지 않는다.
	var spawned_ids := {}
	var floor_ids := {}
	var observed := {"stuck_timeout": false, "game_over": false, "cleared": false,
		"turn_events": [], "returned_at_turn_end": -1}
	ball_container.child_entered_tree.connect(func(node: Node) -> void:
		spawned_ids[node.get_instance_id()] = true)
	# 발사 직후 공은 발사 위치(y=708)에서 Floor 영역과 겹친 채 위로 움직이므로, 하향 진입만 회수로 센다.
	floor_zone.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("ball") and body.linear_velocity.y >= 0:
			floor_ids[body.get_instance_id()] = true)
	scene._stuck_timer.timeout.connect(func() -> void: observed["stuck_timeout"] = true)
	_gm.game_over.connect(func() -> void: observed["game_over"] = true)
	_gm.stage_cleared.connect(func() -> void: observed["cleared"] = true)
	_gm.turn_changed.connect(func(new_turn: int) -> void:
		observed["turn_events"].append(new_turn)
		# advance_turn은 _end_turn 첫 단계에서 호출되므로 이 시점 회수 수가 이번 턴의 최종값이다.
		observed["returned_at_turn_end"] = scene._balls_returned)

	# 1) 신규 저장: 첫 발사 안내가 떠 있고 런처 입력은 막혀 있어야 한다.
	_check("신규 저장에서 첫 발사 안내 표시", tutorial.visible and tutorial._is_active)
	_check("안내 중 런처 입력 차단", not launcher.is_processing_input())
	_check("첫 안내 미확인 상태", not _sm.has_seen_tutorial("first_shot"))

	# 2) 안내를 닫는 누름이 그대로 조준으로 이어져야 한다.
	_send_touch(GESTURE_PRESS, true)
	await _wait_frames(2)
	_check("누름으로 안내 닫힘", not tutorial._is_active)
	_check("같은 누름으로 조준 시작", launcher._is_aiming)
	_check("안내 확인이 테스트 저장에 기록", _sm.has_seen_tutorial("first_shot"))

	# 3) 비수직 경유점을 거쳐 최종점까지 드래그한다. 각 지점에서 조준 방향이 손가락을 따라가는지 확인한다.
	await _drag_path(GESTURE_PRESS, GESTURE_DRAG_VIA, GESTURE_DRAG_STEPS)
	_check_aim(launcher, GESTURE_DRAG_VIA, "드래그 경유점 조준 방향")
	await _drag_path(GESTURE_DRAG_VIA, GESTURE_DRAG_END, GESTURE_DRAG_STEPS)
	_check_aim(launcher, GESTURE_DRAG_END, "드래그 최종점 조준 방향")
	# 공 수는 게임 상태가 아니라 레벨 JSON에서 독립적으로 가져온다.
	var expected_balls: int = int(_read_level_expectation(TURN_LEVEL).get("initial_balls", -1))
	_check("발사 직전 공 수가 레벨 초기값", _gm.ball_count == expected_balls, "%d / 기대 %d" % [_gm.ball_count, expected_balls])
	_send_touch(GESTURE_DRAG_END, false)
	var is_firing := await _wait_until(func() -> bool: return scene._state != STATE_AIMING, 10)
	_check("해제로 발사 시작", is_firing, "state=%d" % scene._state)

	# 4) 턴 종료(턴 +1)를 기다린 뒤, 하강을 마치고 다시 조준 가능한 상태가 될 때까지 기다린다.
	var is_turn_done := await _wait_until(func() -> bool:
		return observed["turn_events"].size() > 0 or observed["cleared"] or observed["game_over"]
	, TURN_MAX_FRAMES)
	_check("제한 프레임 안에 턴 종료", is_turn_done)
	var is_next_aiming := await _wait_until(func() -> bool:
		return scene._state == STATE_AIMING and launcher.is_processing_input()
	, SCENE_READY_MAX_FRAMES)

	_check("생성된 공 수", spawned_ids.size() == expected_balls, "%d / 기대 %d" % [spawned_ids.size(), expected_balls])
	_check("하향 바닥 도달 공 수(관찰, 중복 제외)", floor_ids.size() == expected_balls, "%d / 기대 %d" % [floor_ids.size(), expected_balls])
	_check("정상 하향 회수 수(턴 종료 시점)", observed["returned_at_turn_end"] == expected_balls, "%d / 기대 %d" % [observed["returned_at_turn_end"], expected_balls])
	_check("안전 타이머 시간 초과 없음", not observed["stuck_timeout"])
	_check("스테이지 클리어 없음", not observed["cleared"])
	_check("게임오버 없음", not observed["game_over"])
	var expected_turn := 2 if _is_self_test_fail else 1  # 자가 검사: 일부러 틀린 기대값
	_check("턴 0→1 정확히 한 번", observed["turn_events"] == [expected_turn], observed["turn_events"])
	_check("남은 공 없음", ball_container.get_child_count() == 0, ball_container.get_child_count())
	_check("배속 원복", is_equal_approx(Engine.time_scale, 1.0), Engine.time_scale)
	_check("다음 턴 AIMING 복귀 및 입력 활성", is_next_aiming)

	# 5) 다음 턴에서 실제 누름·드래그로 조준이 시작되는지 확인한다(해제하지 않아 두 번째 턴은 만들지 않는다).
	if is_next_aiming:
		_check("다음 턴 누르기 전 조준 비활성", not launcher._is_aiming)
		_send_touch(GESTURE_PRESS, true)
		await _wait_frames(2)
		_check("다음 턴 누름으로 조준 시작", launcher._is_aiming)
		await _drag_path(GESTURE_PRESS, NEXT_TURN_DRAG_END, GESTURE_DRAG_STEPS)
		_check_aim(launcher, NEXT_TURN_DRAG_END, "다음 턴 드래그 조준 방향")


# 런처의 조준 방향이 발사점에서 목표 지점을 향하는지 확인한다.
func _check_aim(launcher: Node, target: Vector2, name: String) -> void:
	var expected_dir: Vector2 = (target - launcher.launch_point.global_position).normalized()
	var actual_dir: Vector2 = launcher._aim_direction
	var diff := absf(actual_dir.angle_to(expected_dir))
	_check(name, diff <= AIM_TOLERANCE_RAD, "실제 %s / 기대 %s" % [actual_dir, expected_dir])


# ── 케이스: 수평에 가까운 공의 각도 보정 ────────────────────────

# 거의 수평으로 움직이는 공이 벽에 튄 뒤 최소 각도로 보정되는지 확인한다.
# 공 물리 단위 검사다. 실제 입력 흐름은 turn 케이스가 맡고, 여기서는 공을 직접 발사해 조건을 고정한다.
func _case_ball_angle() -> void:
	_gm.current_level = TURN_LEVEL
	var scene := await _change_scene_and_wait(TURN_SCENE_PATH)
	if scene == null:
		return
	# 벽돌이 없는 높이(y=600)에서 오른쪽 벽을 향해 발사한다. 씬의 BallContainer는 턴 흐름에 쓰이므로 피한다.
	var ball: RigidBody2D = (load(BALL_SCENE_PATH) as PackedScene).instantiate()
	scene.add_child(ball)
	ball.global_position = Vector2(240, 600)
	ball.setup(400.0)
	ball.launch(NEAR_HORIZONTAL_DIR)
	var is_bounced := await _wait_until(func() -> bool:
		return ball.linear_velocity.x < 0
	, BOUNCE_MAX_FRAMES)
	_check("오른쪽 벽에서 반사", is_bounced, ball.linear_velocity)
	if not is_bounced:
		return
	# 각도 보정은 call_deferred로 적용되므로 몇 프레임 기다린다.
	await _wait_frames(3)
	var velocity := ball.linear_velocity
	var angle_deg := rad_to_deg(absf(atan2(velocity.y, absf(velocity.x))))
	_check("반사 후 수평에서 %.0f° 이상" % MIN_HORIZONTAL_DEG, angle_deg >= MIN_HORIZONTAL_DEG - 0.01, "%.3f°" % angle_deg)
	_check("반사 후 하향 유지(바닥 회수 방향)", velocity.y > 0, velocity)
	_check("반사 후 속도 유지", is_equal_approx(velocity.length(), 400.0), velocity.length())
	ball.queue_free()


# ── 케이스: 조준 각도 한계 ───────────────────────────────────────

# 각도 한계를 넘는 드래그는 같은 쪽 한계 각도로 잘려야 한다(반대쪽으로 뒤집히면 안 된다). 실제 입력으로 검증한다.
func _case_aim_clamp() -> void:
	_gm.current_level = TURN_LEVEL
	var scene := await _change_scene_and_wait(TURN_SCENE_PATH)
	if scene == null:
		return
	var launcher: Node = scene.get_node("Launcher")
	# 신규 저장이므로 첫 안내가 떠 있다. 안내를 닫는 누름으로 조준을 시작한다.
	_send_touch(GESTURE_PRESS, true)
	await _wait_frames(2)
	_check("누름으로 조준 시작", launcher._is_aiming)
	var limit_rad := deg_to_rad(AIM_LIMIT_FROM_UP_DEG)
	await _drag_path(GESTURE_PRESS, AIM_OVER_LIMIT_RIGHT, GESTURE_DRAG_STEPS)
	_check_aim_dir(launcher, Vector2(sin(limit_rad), -cos(limit_rad)), "오른쪽 한계 초과 드래그 → 오른쪽 85°")
	await _drag_path(AIM_OVER_LIMIT_RIGHT, AIM_OVER_LIMIT_LEFT, GESTURE_DRAG_STEPS)
	_check_aim_dir(launcher, Vector2(-sin(limit_rad), -cos(limit_rad)), "왼쪽 한계 초과 드래그 → 왼쪽 85°")
	# 한계 안쪽 드래그는 그대로 따라가야 한다(자르기 수정이 정상 범위를 건드리지 않는지 확인).
	await _drag_path(AIM_OVER_LIMIT_LEFT, GESTURE_DRAG_VIA, GESTURE_DRAG_STEPS)
	_check_aim(launcher, GESTURE_DRAG_VIA, "한계 안쪽 드래그는 그대로")


# 런처의 조준 방향이 기대 방향과 같은지 확인한다.
func _check_aim_dir(launcher: Node, expected_dir: Vector2, name: String) -> void:
	var actual_dir: Vector2 = launcher._aim_direction
	var diff := absf(actual_dir.angle_to(expected_dir))
	_check(name, diff <= AIM_TOLERANCE_RAD, "실제 %s / 기대 %s" % [actual_dir, expected_dir])


# ── 결과 출력 ───────────────────────────────────────────────────

# 결과를 출력하고 PASS/FAIL 종료 코드로 끝낸다.
func _finish() -> void:
	var is_pass := not _checks.is_empty()
	for c in _checks:
		if not c["ok"]:
			is_pass = false
	_emit_result(is_pass, "")
	quit(EXIT_PASS if is_pass else EXIT_FAIL)


# 환경 문제로 검사를 진행할 수 없을 때 결과를 출력하고 종료 코드 2로 끝낸다.
func _finish_env_error(message: String) -> void:
	push_error("P0 환경 오류: %s" % message)
	_emit_result(false, message)
	quit(EXIT_ENV)


# 출력 계약에 맞춰 결과 JSON 한 줄을 stdout에 쓴다.
func _emit_result(is_pass: bool, env_error: String) -> void:
	Engine.time_scale = 1.0
	var result := {
		"case": _case,
		"level": _level if _case == "load" else (TURN_LEVEL if _case == "turn" else 0),
		"pass": is_pass,
		"env_error": env_error,
		"checks": _checks,
		"save_path_global": ProjectSettings.globalize_path(_save_path) if _save_path != "" else "",
	}
	print("P0_RESULT " + JSON.stringify(result))
