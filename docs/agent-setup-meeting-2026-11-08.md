# 에이전트 세팅 회의 결과 (2026-11-08)

- 안건 문서: [agent-setup-discussion.md](agent-setup-discussion.md)
- 참석: Claude Code(진행), Codex(독립 검토, Orca 워커)
- 방식: 1라운드 Codex 독립 검토 → 2라운드 Claude 반론 4건 → 합의
- 상태: **계획 합의만 완료. 코드 변경 없음.**

## 1. 문서와 코드 불일치 (확인됨)

안건 문서가 지적한 "7열/10열" 외에도 `CLAUDE.md`의 구현 수치가 실제 코드와 다르다.

| 항목 | CLAUDE.md | 실제 코드 |
| --- | --- | --- |
| 연사 간격 | 0.05초 | `FIRE_INTERVAL = 0.08` (`scripts/objects/launcher.gd:11`) |
| 그리드 상단 / 바닥 | 84 / 744 | 78 / 708 (`scripts/turn_game_scene.gd:17,19`) |
| 그리드 열 수 | 7열 설명 혼재 | 10열 (`scripts/turn_game_scene.gd:15`, `scripts/stage_preview_popup.gd:11`) |
| WAITING 안전 타이머 | 주석 20초 | 실제 60초 (`scripts/turn_game_scene.gd:270-271`) |
| 공 각도 보정 | 수평 ±15도 차단 | 수직 상향 8도 미만 보정 (`scripts/objects/ball.gd`, Codex 보고·미재확인) |

## 2. 검토 중 드러난 위험

- **저장 격리 시점**: SaveManager는 첫 autoload이고 `_ready()`에서 즉시 `user://save_data.json`을 읽는다. 테스트 스크립트에서 나중에 경로를 바꾸면 늦다.
- **저장은 종료 시점만이 아님**: 첫 발사 안내 확인, 기믹 안내 OK, 설정 닫기, 스테이지 클리어 때마다 즉시 파일에 쓴다.
- **첫 발사 안내 = 조준 인계**: 안내를 닫는 같은 터치가 그대로 조준으로 이어진다. 안내를 이미 본 저장 데이터로만 테스트하면 이 경로의 회귀를 놓친다.
- **턴 +1만으로는 부족**: 공이 회수되지 않아도 60초 안전 타이머가 공을 지우고 턴을 끝낸다. 또 턴 카운터는 벽돌 하강보다 먼저 증가한다.
- **레벨 로드 실패가 조용함**: JSON 오류는 `push_error` 후 return만 하고 씬은 계속 진행한다. 빈 씬도 "로드 성공"처럼 보일 수 있다.
- **실행 환경**: WSL PATH에 Godot이 없다. 발견한 `Godot_v4.6.1-stable_win64_console.exe`는 본체를 찾지 못해 실패한다(exit 255).

## 3. 질문별 결론

### Q1. 규칙 정리
- `AGENTS.md`: 공통 규칙(한국어 주석·커밋, 네이밍, 사용자 최신 지시 우선, 사용자 편집 보존, 검증 결과를 PASS/FAIL/미실행으로 구분, 테스트 저장 격리와 우회 호출 금지).
- 구현 맥락(autoload 책임, 상태 머신, 충돌 레이어, 레이아웃, 레벨 JSON 형식)은 코드 기준으로 교정해 별도 문서(예: `docs/architecture.md`)로 분리한다.
- `CLAUDE.md`는 `@AGENTS.md`와 구현 문서 링크만 둔다.
- "모든 함수 주석 필수", "시그널은 모두 `_ready`", "gd:tscn 1:1" 같은 절대 규칙은 실제 코드에 예외가 있으므로 완화한다.

### Q2. 첫 P0 구성
- **P0-A** 타이틀 씬 기동
- **P0-B** level_1~5를 실제 게임 씬에서 로드
- **P0-C** 신규 저장 상태에서 레벨 1 첫 발사 안내 → 같은 터치로 조준 → 드래그 → 해제 → 한 턴 완료
- 첫 안내를 실제 입력으로 닫는 검증은 P1로 미루지 않고 P0-C에 포함한다.

### Q3. 저장 격리와 실행 방식
- **채택**: SaveManager `_ready()`에서 `load_data()` 전에 실행 인자 `--save-path=user://p0/<uuid>.json`를 읽는다.
  - 읽기·쓰기 모두 같은 `_save_path`를 사용한다.
  - 인자 형식 검증과 `p0` 디렉터리 생성을 넣고, 실패하면 원본 경로로 fallback하지 않고 종료(exit 2)한다.
  - 인자가 없으면 기존 동작을 그대로 유지한다.
- **기각**: 임시 프로젝트 복사 + `custom_user_dir`. 정확하지만 매 실행 assets 복사와 재import 비용이 크다.
- 로그도 `--log-file`로 분리한다(기본 로그는 `user://logs/godot.log`).
- 보장 범위: 기존 `save_data.json`과 로그만 보존한다. 셰이더·엔진 캐시를 포함한 `user://` 전체 무변경은 보장하지 않는다.

실행 명령(구현 후):
```
python3 tools/run_p0.py --godot "<정상 Godot 4.6.x 실행 파일>" --suite p0
```
래퍼 내부:
```
<godot> --headless --path <Windows 형식 프로젝트 경로> --log-file <UUID 임시 로그> \
  --script res://tests/p0_runner.gd -- --save-path=user://p0/<uuid>.json
```

종료 코드:

| 코드 | 의미 |
| --- | --- |
| 0 | 모든 케이스 PASS + 결과 JSON 존재 + SCRIPT ERROR 없음 |
| 1 | 기대값 불일치, 스크립트·엔진 오류, 크래시 |
| 2 | 엔진 없음, 버전 부적합, 격리 준비 실패 |
| 124 | 시간 초과 |

### Q4. 첫 P1 우선순위
1. **HUD 입력 회귀**: 일시정지·재개·설정 닫기 시 발사 0회, 턴 변화 0. 과거 회귀 이력(`docs/input-handling-review-2026-04-12.md`)이 있고 런처가 hover에 의존한다.
2. **저장 재로드**: 별도 프로세스 재기동 후 first_shot 확인 상태 유지부터 시작해 해금·별·볼륨으로 확장한다.
3. **특수 기믹**: 레이저·미사일·공 아이템 정산. shuffle 난수가 있으므로 불변조건을 먼저 정의한다.

## 4. 2라운드 쟁점과 합의

| 쟁점 | Claude 제안 | 합의 |
| --- | --- | --- |
| 저장 격리 | 임시 복사 대신 SaveManager 인자 | 채택. 경로 검증, 디렉터리 생성, 로그 분리 보완 |
| 레벨 기대값 | 하드코딩 대신 JSON에서 계산 | 채택. 게임 로더를 재사용하지 않는 독립 관찰 |
| 1차 범위 | 9개 → 6개로 축소 | 채택. 3회 연속 PASS·하강 1셀 검증은 1.1로 이관 |
| 래퍼 | `python3 tools/run_p0.py` 하나 | 채택. `wslpath -w` 경로 변환, 타임아웃 시 자식 프로세스 종료 확인 |

## 5. 1차 완료 기준

- [ ] (a) `AGENTS.md` 공통 규칙 정리 + `CLAUDE.md` import, 낡은 수치 교정, 구현 맥락 분리
- [ ] (b) Godot 4.6.x 버전 문자열 실제 확인, 엔진 부재·부적합·격리 실패 시 exit 2
- [ ] (c) 최초 load 전 `_save_path` 결정, UUID 저장·로그 분리, 원본 저장 전후 SHA256 동일(원래 없으면 계속 없음), 무인자 실행 시 기존 경로 유지
- [ ] (d) 타이틀 ready + level_1~5 실제 씬 로드, JSON에서 계산한 개수·HP·속도·초기 공 수와 일치
- [ ] (e) 신규 저장 첫 안내에서 `InputEventScreenTouch/Drag` 단일 제스처로 인계 → 해제 → 한 턴. 생성 공 N개 = 정상 Floor 회수 N개(인스턴스 ID 기준 중복 없이, 레벨 1은 N=50). 안전 타이머 timeout 0, 클리어·게임오버 없음, 턴 0→1, 하강 후 다시 조준 가능
- [ ] (f) 단일 명령 PASS 1회 + 일부러 틀린 기대값으로 exit 1 + 짧은 watchdog으로 exit 124 각 1회

테스트 금지 사항: `_dismiss`, `begin_aiming_from`, `start_firing`, `_end_turn`, `_load_level` 직접 호출과 버튼 시그널 수동 emit.

**1.1로 이관**: 3회 연속 재실행, 하강 1셀 대조, P1 착수.

## 6. 역할 분담

| 담당 | 작업 | 교차 검토 대상 |
| --- | --- | --- |
| Claude | `AGENTS.md`/`CLAUDE.md`, 구현 맥락 문서, `tests/p0_runner.gd` | Codex의 최초 읽기 전 격리, 무인자 호환, timeout 처리 |
| Codex | `tools/run_p0.py`, `scripts/autoload/save_manager.gd` 경로 인자 | Claude의 입력 우회 여부, Floor 정상 회수, 다음 조준 판정 |

통합 후 같은 명령으로 각자 재실행하고, 엔진 버전·실제 저장 경로·종료 코드·결과 JSON·로그를 교환한다. 화면·소리·실제 터치 조작감은 별도로 수동 확인하거나 "미확인"으로 기록한다.

## 7. 미결 사항

1. **정상 Godot 4.6 실행 파일 확보**: 없으면 (b)~(f)를 실행할 수 없다.
2. **규칙 파일의 git 공유 여부** → 해결: 다른 PC에서도 Claude·Codex로 작업하므로 `AGENTS.md`, `CLAUDE.md`, `docs/architecture.md`, 이 회의 문서는 git에 올린다. 나머지 `docs/`는 로컬 전용이다(`docs/*` + 예외).
3. **자동 `git add` 출처 미확인**: 세션 중 untracked 파일이 주기적으로 staged되는 현상이 있었다. Claude와 Codex가 실행한 명령은 아니며, Windows 쪽 도구로 추정한다.
4. **미확인 항목**: 레벨 1 고정 샷 좌표(후보 (240,650)→(300,400)), 케이스별 시간 예산, headless에서 합성 터치와 hover 판정의 실제 동작, 레벨 5의 벽돌·아이템 겹침 의도.

## 8. 구현 결과 (2026-11-08 같은 날)

1차 완료 기준 (a)~(f)를 모두 충족했다. 교차 검토도 마쳤다.

| 기준 | 결과 |
| --- | --- |
| (a) 규칙 문서 | `AGENTS.md` 정리, `docs/architecture.md` 신설(수치 교정), `CLAUDE.md`는 `@` import만 |
| (b) 엔진 확인 | Godot 4.6.1 (`D:\Program Files\Godot\Godot_v4.6.1-stable_win64.exe`), 잘못된 엔진 → exit 2 |
| (c) 저장 격리 | SaveManager `--save-path` 인자(Codex). 원본 SHA256 `6fae49f7…` 모든 실행 전후 동일 |
| (d) 타이틀 + 5레벨 | PASS, JSON에서 독립 계산한 기대값과 일치 |
| (e) 한 턴 | PASS. 25개 검사: 안내 인계, 비수직 경유점 조준 방향, 공 50 생성·50 하향 회수, timeout 0, 턴 0→1, 다음 턴 조준 |
| (f) 실패 판정 | 정상 0(여러 회), `--self-test fail` → 1, `--self-test timeout` → 124 |

결정 사항
- 고정 샷은 (240,100) 수직 발사로 정했다. 후보 6개 중 5개는 통과했고, 낮게 오른쪽으로 쏜 (460,600)은 레벨 1이 한 턴에 클리어됐다.
- 경유점은 (100,400)으로 정했다. 드래그 처리가 실제로 조준을 바꾸는지 확인하려는 것이다(Codex 교차 검토 반영).
- 기대 공 수는 게임 상태가 아니라 레벨 JSON의 `initial_balls`에서 가져온다(Codex 교차 검토 반영).

구현 중 발견
- headless는 창 크기가 0이라 늘이기 변환이 0.073배다. 주입 좌표는 `root.get_final_transform()`으로 변환해야 한다.
- 발사 직후 공이 y=708에서 Floor 영역과 겹치면서 상향 `body_entered`가 발생한다. 관찰 집계는 하향 진입만 센다.
- **게임 버그 후보 1**: `_on_floor_body_entered`가 물리 콜백 안에서 `body.freeze = true`를 설정해 회수마다 "Can't change this state while flushing queries" 오류가 난다(`scripts/turn_game_scene.gd:291`). `set_deferred` 수정 후보이며 미수정.
- **게임 버그 후보 2**: 거의 수평(85°)으로 쏘면 공 하나가 바닥선 y=708을 따라 굴러가며 회수되지 않고, 60초 안전 타이머로 턴이 끝났다. 원인은 확인하지 않았다.

다음 단계(1.1): 3회 연속 재실행, 하강 1셀 대조, P1(HUD 입력 회귀 → 저장 재로드 → 특수 기믹), 위 버그 후보 처리 여부 결정.

## 9. 버그 수정 (2026-11-08)

| 버그 | 근본 원인 | 수정 | 검증 |
| --- | --- | --- | --- |
| 바닥 회수마다 엔진 오류 | `body_entered` 물리 콜백 안에서 `body.freeze = true` 설정 | `body.set_deferred("freeze", true)` (`scripts/turn_game_scene.gd`) | 한 턴 오류 50건 → 0건, P0 PASS |
| 수평 발사 시 공이 회수되지 않음 | `_correct_velocity`에 수평 보정이 없음. 0.2°로 좌우 벽만 왕복(왕복당 3px 하강) → 60초 안전 타이머 | 수평 5° 미만이면 위아래로 틀기 (`scripts/objects/ball.gd`) | 새 `ball_angle` 케이스 실패(0.229°) → 통과(5.000°). 재현 샷 6/6 정체 → 3/3 정체 없음 |

| 조준 각도 한계를 넘으면 반대쪽으로 뒤집힘 | `_update_aim`이 `raw_dir.angle_to(UP)`(raw→UP)로 잰 각도를 `UP.rotated()`(UP→raw)에 그대로 써서 부호가 반대 | `Vector2.UP.angle_to(raw_dir)`로 변경 (`scripts/objects/launcher.gd`) | 새 `aim_clamp` 케이스(실제 드래그 입력) 좌우 모두 실패 → 통과, 한계 안쪽 드래그는 변화 없음 |
