# 구현 구조

턴제 벽돌깨기의 구현 맥락이다. 2026-11-08 기준 코드에서 확인한 값이며, 수치가 다르면 코드가 기준이다.
작업 규칙은 [AGENTS.md](../AGENTS.md)에 있다.

## Autoload 싱글톤

`project.godot`에 등록된 순서대로 생성된다.

| 순서 | 이름 | 역할 |
| --- | --- | --- |
| 1 | `SaveManager` | `user://save_data.json` 영속 데이터. 해금 레벨, 최저 턴, 별, 볼륨, 튜토리얼 확인 상태 |
| 2 | `GameManager` | 한 판의 휘발성 상태(`current_level`, `turn_count`, `ball_count`, `score`, `combo`). 시그널 `turn_changed`, `ball_count_changed`, `score_changed`, `game_over`, `stage_cleared` |
| 3 | `SoundManager` | BGM/SFX 버스 관리, SFX 플레이어 풀 5개(`SFX_POOL_SIZE`) |

### 저장 타이밍 주의
- `SaveManager._ready()`에서 즉시 `load_data()`로 파일을 읽는다(`scripts/autoload/save_manager.gd:22`).
- 저장은 게임 종료 때만 하지 않는다. 첫 발사 안내 확인, 기믹 안내 OK, 설정 닫기, 반복 튜토리얼 토글, 스테이지 클리어 때마다 즉시 쓴다.

## 게임 흐름

```
title_screen → stage_select → turn_game_scene → (결과 팝업) → stage_select
```

- 결과 팝업은 `scenes/ui/game_result_popup.tscn`이고 스크립트는 `scripts/game_over_menu.gd`다.
- 비활성 파일: `game_scene.tscn/gd`, `paddle.tscn/gd`, `power_up.tscn/gd`는 클래식 모드용으로 보존 중이며 현재 GameManager와 호환되지 않는다.

## 턴 루프 (`scripts/turn_game_scene.gd`)

```
AIMING → FIRING → WAITING → TURN_END → AIMING
```

- **AIMING**: Launcher가 레이캐스트 기반 점선 가이드(1바운스 미리보기)를 표시한다. 첫 턴에 첫 발사 안내가 뜨면, 안내를 닫는 같은 터치가 바로 조준으로 이어진다(`begin_aiming_from`).
- **FIRING**: `FIRE_INTERVAL = 0.08`초 간격으로 공을 연사한다(`scripts/objects/launcher.gd:11`).
- **WAITING**: 공 회수를 기다린다. 실시간 5초 후 2배속, 10초 후 3배속.
  - 안전 타이머 `_stuck_timer`는 WAITING 진입 시 60초(게임 시간)로 시작한다. 시간이 다 되면 남은 공을 지우고 턴을 끝낸다. 주석의 "20초"는 실제 값과 다르다.
  - 공 전체 회수 버튼과 스테이지 클리어 시 강제 회수도 별도 경로로 턴을 끝낸다.
- **TURN_END** 순서: `GameManager.advance_turn()`(턴 +1) → 벽돌 하강 → 게임오버 체크 → 클리어 체크 → 공 아이템 정산 → AIMING.
  - 턴 카운터는 하강보다 **먼저** 증가한다.

## 화면 레이아웃 (480×854)

```
  0px ┌────────────────────────────┐
      │      TOP HUD (76px)        │
 76px ├════════════════════════════╡ ← CeilingWall (76~78, 2px)
      ║                            ║
      ║      PLAY AREA             ║ ← LeftWall / RightWall (ColorRect)
      ║                            ║
708px ╠════════════════════════════╣ ← FloorWall (708~712, 4px)
      │   BOTTOM AREA (142px)      │
854px └────────────────────────────┘
```

| 항목 | 값 | 위치 |
| --- | --- | --- |
| 그리드 열 수 | `GRID_COLS = 10` | `scripts/turn_game_scene.gd:15` |
| 셀 크기 | 정사각형, 뷰포트 너비 / 10 = 48px | `_load_level` |
| 그리드 상단 | `GRID_TOP_OFFSET = 78` | `scripts/turn_game_scene.gd:17` |
| 발사 라인 | `FLOOR_Y = 708` (Launcher Y) | `scripts/turn_game_scene.gd:19` |
| 초기 최하단 행 | `INITIAL_BOTTOM_ROW = 6` | `scripts/turn_game_scene.gd:20` |
| 벽 물리 | WallTop Y=66, WallLeft X=-10, WallRight X=490 (StaticBody2D) | `scenes/turn_game_scene.tscn` |
| 바닥 감지 | Floor(Area2D) Y=718 | `scenes/turn_game_scene.tscn:152` |

- 스테이지 미리보기 팝업도 10열이다(`scripts/stage_preview_popup.gd:11`).
- 레벨의 가장 아래 행이 `INITIAL_BOTTOM_ROW`에 오도록 `_row_offset`을 계산한다. 그래서 위쪽 오브젝트는 처음에 화면 밖(음수 Y)에 있을 수 있다.

## 충돌 레이어

| Layer | 대상 | 용도 |
| --- | --- | --- |
| 1 | 벽, 벽돌 | 기본 물리 |
| 2 | 공 | 공끼리 충돌하지 않음(공의 mask=1) |

Floor, BallItem, LaserShooter(Area2D)는 `collision_layer=0`, `collision_mask=2`로 공만 감지한다.

## 벽돌 (`scripts/objects/brick.gd`)

- **사각형**: Sprite2D + RectangleShape2D, Kenney 텍스처.
- **직각삼각형**: Polygon2D + CollisionPolygon2D, 단색 채움. 방향 `dir` 0:◣ 1:◢ 2:◤ 3:◥.
- **HP 색상**: Green(1~10), Orange(11~30), Red(31 이상), Grey(파괴 불가, `hp = -1`).
- HP 라벨을 위에 겹쳐 표시한다.
- `item: "missile"`이면 아이템 박스로 표시되고, 파괴되면 미사일 아이템이 발동한다.

## 공 (`scripts/objects/ball.gd`)

- RigidBody2D, bounce 1.0, gravity 0, CCD 사용.
- `_physics_process`에서 매 프레임 속도를 `_target_speed`로 유지한다. 완전히 멈춘 공은 아래로 밀어 바닥으로 회수한다.
- 충돌 후(벽 포함, `contact_monitor` 사용) `call_deferred`로 각도를 보정한다.
  - 수직 상향 8°(`MIN_ANGLE_RAD`) 미만 → 옆으로 튼다.
  - 수평 5°(`MIN_HORIZONTAL_ANGLE_RAD`) 미만 → 위아래로 튼다. 완전 수평이면 아래로 튼다. 조준 한계와 같은 값이라 정상 발사 궤적은 바뀌지 않는다. (2026-11-08 추가: 0.2°로 좌우 벽만 왕복하며 회수되지 않던 공 수정)
- 바닥 회수 시 `freeze`는 `set_deferred`로 설정한다. 물리 콜백 안에서는 바디 모드를 바꿀 수 없다.

## 레벨 데이터 (`data/levels/level_N.json`)

```json
{
  "ball_speed": 400,
  "initial_balls": 50,
  "star_thresholds": [10, 7, 4],
  "bricks": [
    {"row": 0, "col": 3, "hp": 40},
    {"row": 1, "col": 2, "hp": 20, "type": "tri", "dir": 0},
    {"row": 2, "col": 5, "hp": 10, "item": "missile"}
  ],
  "ball_items": [{"row": 1, "col": 1}],
  "laser_shooters": [{"row": 3, "col": 4, "uses": 10, "damage": 1, "dirs": [0]}]
}
```

- `type`을 생략하면 사각형이고, `"tri"`면 `dir`이 필요하다.
- `star_thresholds`: [1성, 2성, 3성] 기준 턴 수. 이 값 이하로 클리어하면 획득한다.
- `laser_shooters`의 `uses`, `damage`, `dirs`는 생략하면 각각 10, 1, `[0]`이다.
- 그리드는 10열이다.
- 파일이 없거나 JSON 파싱에 실패하면 `push_error`만 남기고 씬은 계속 진행된다. 빈 씬이 될 수 있으니 로드 확인 시 실제 오브젝트 수를 봐야 한다.
- level_5에는 벽돌과 공 아이템이 같은 칸(row 5, col 4/5)에 있다. 의도한 배치인지는 확인하지 않았다.
