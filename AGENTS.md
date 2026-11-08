# 프로젝트 작업 규칙

Codex와 Claude Code가 함께 따르는 공통 규칙이다. Claude Code는 `CLAUDE.md`의 `@AGENTS.md`로 이 파일을 읽는다.
구현 구조(상태 머신, 레이아웃 수치, 충돌 레이어, 레벨 JSON 형식)는 [docs/architecture.md](docs/architecture.md)에 있다.

## 목적과 실행

- Godot 4.6 모바일 턴제 벽돌깨기 게임이다. 480×854 세로 화면을 쓰고 Mobile 렌더러를 사용한다.
- 시작점은 `project.godot`이고 메인 씬은 `res://scenes/title_screen.tscn`이다.
- 실행: Godot 4.6 에디터에서 프로젝트를 열고 `F5`. 마우스 터치 에뮬레이션이 켜져 있다.
- 레벨 에디터: `python3 tools/run_editor.py` 후 `http://localhost:8190/tools/level_editor.html`. Windows는 `tools/editor.bat`.
- 패키지 매니저, 빌드 파이프라인, CI는 없다.

## 폴더 구성

| 경로 | 내용 |
| --- | --- |
| `scenes/`, `scenes/ui/`, `scenes/objects/` | 게임 씬, UI 팝업, 오브젝트 프리팹 |
| `scripts/` | 씬에 대응하는 GDScript. 공용 싱글톤은 `scripts/autoload/` |
| `data/levels/level_*.json` | 레벨 데이터 |
| `assets/` | 이미지, 폰트, 사운드 |
| `tests/` | P0 자동 검사 시나리오 (`p0_runner.gd`) |
| `tools/` | 브라우저 기반 레벨 에디터, P0 실행기 (`run_p0.py`) |
| `docs/` | 기획·리뷰·회의 문서. git에는 `architecture.md`, `agent-setup-meeting-2026-11-08.md`, `superpowers/`만 올라가고 나머지는 로컬 전용이다 |

## 변경 원칙

- 사용자의 최신 명시적 요청과 이 문서가 충돌하면 최신 요청을 따른다.
- 사용자가 직접 편집한 내용을 확인하고 보존한다. 요청 범위 밖의 파일은 바꾸지 않는다.
- 관련 호출부와 데이터 흐름을 확인하고 기존 구현을 재사용한다.
- 요구사항이나 접근 방식에 문제가 있으면 근거(file:line)와 대안을 먼저 설명한다.
- 작업별 결정은 `docs/`의 해당 기획·리뷰 문서에 날짜와 이유를 남긴다. 이 파일에는 오래 유지할 규칙만 둔다.
- git 인덱스나 히스토리를 바꾸는 명령(add, commit, restore 등)은 사용자가 요청했을 때만 실행한다.

## 코딩 규칙

- GDScript는 Godot 4 문법을 쓴다. 들여쓰기는 탭이다.
- 함수·시그널은 `snake_case`, private 멤버는 `_snake_case`, 상수는 `UPPER_SNAKE_CASE`.
- 불리언은 `is_`, `has_`, `can_` 접두사를 쓴다.
- 주석, 응답, 커밋 메시지는 한국어로 작성한다.
- 함수 상단에는 목적을 한 줄로 설명한다. 이름만으로 의도가 분명한 짧은 getter는 생략할 수 있다.
- 씬과 스크립트는 대응 관계를 유지한다. 예: `scenes/turn_game_scene.tscn` ↔ `scripts/turn_game_scene.gd`. 단 `scenes/ui/game_result_popup.tscn`은 `scripts/game_over_menu.gd`를 쓰는 기존 예외다.
- 시그널은 기본적으로 `_ready()`에서 연결한다. 동적으로 생성한 노드나 일회성 연결(`CONNECT_ONE_SHOT`)은 생성 지점에서 연결해도 된다.
- 트윈 애니메이션은 `create_tween()`을 사용한다.

## 커밋과 PR

- 형식: `추가:`, `수정:`, `개선:`, `정리:` 같은 한국어 타입 접두사 + 짧은 설명. 예: `수정: 레이저 충돌 처리 중복 방지`
- 커밋은 한 가지 주제로 작게 나눈다.
- PR에는 변경 요약, 영향받는 씬·스크립트, 테스트 결과를 적는다. UI나 연출 변경은 스크린샷이나 짧은 영상을 첨부한다.

## 검증과 완료

- **P0 자동 검사** (타이틀 기동, 레벨 1~5 로드, 레벨 1 첫 안내 + 터치 한 턴, 수평 공 각도 보정, 조준 각도 한계, 약 15초):
  ```
  python3 tools/run_p0.py --godot '<Godot 4.6.x 실행 파일 경로>' --suite p0
  ```
  - `--godot` 예시(PC마다 다름): `'D:\Program Files\Godot\Godot_v4.6.1-stable_win64.exe'`. WSL에서는 Windows 경로와 `/mnt/d/...` 경로를 모두 받는다.
  - 종료 코드: 0=PASS, 1=FAIL(원본 저장 변경 포함), 2=엔진·격리 준비 실패, 124=시간 초과.
  - 케이스마다 headless Godot을 따로 띄우고 `--save-path=user://p0/<uuid>.json`으로 저장을 격리한다. 실패한 케이스의 로그와 저장은 `user://p0/`에 남는다.
  - 시나리오는 `tests/p0_runner.gd`, 실행기는 `tools/run_p0.py`에 있다. 범위와 결정 배경은 `docs/agent-setup-meeting-2026-11-08.md`에 있다.
  - 게임 로직, 공 물리, 턴 진행, 저장, 레벨 JSON을 바꿨다면 P0를 실행한다.
- 자동 테스트를 만들거나 고칠 때 지킬 것:
  - 실제 저장 파일 `user://save_data.json`을 건드리지 않는다. 테스트 저장 경로는 SaveManager가 처음 읽기 전에 결정되어야 한다.
  - 검증 대상 동작은 실제 입력(`InputEventScreenTouch`/`InputEventScreenDrag`)으로 일으킨다. `_load_level`, `start_firing`, `_end_turn` 같은 내부 함수 직접 호출이나 버튼 시그널 수동 emit으로 우회하지 않는다.
  - 제한 시간을 두고, 성공·실패·시간 초과를 종료 코드로 구분한다.
  - headless는 창 크기가 0이다. `Input.parse_input_event`에는 뷰포트 좌표를 `root.get_final_transform()`으로 변환해서 넣는다.
  - `--script` 모드에서는 autoload 이름을 컴파일 시점에 쓸 수 없다. `root.get_node("GameManager")`처럼 노드로 참조한다.
- 수동 확인: 타이틀 → 스테이지 선택 → 턴 진행 → 일시정지·설정 → 클리어·게임오버 → 저장 반영.
- 레벨 JSON을 바꿨다면 레벨 에디터에서 검증하고, 실제 게임에서 해당 스테이지가 파싱 오류 없이 로드되는지 확인한다.
- 작업 결과 보고는 세 가지를 구분한다.
  1. 자동 검사 결과: PASS / FAIL / 실행 못 함(이유)
  2. 실제 화면·소리·조작 확인 여부
  3. 확인하지 못한 항목

## 여러 에이전트 작업

- 작업을 나눌 때는 담당 파일과 통합 담당자를 정하고, 같은 파일을 동시에 고치지 않는다.
- 인계에는 사용자 요청 원문, 먼저 읽을 자료, 수정 범위, 제약, 완료 기준, 검증 방법을 적는다.
- 결과를 받은 쪽은 변경 파일을 요구사항과 대조하고, 통합 상태에서 검사를 다시 실행한다.
