# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 모바일 턴제 벽돌깨기 게임 (Ballz/BBTAN 스타일). 480x854 세로 모드, 모바일 렌더러 사용.

## Running the Project

Godot 4.6 에디터에서 열고 F5로 실행. 별도 빌드 시스템 없음.
- Main scene: `res://scenes/title_screen.tscn`
- 터치 에뮬레이션 활성화 (마우스로 테스트 가능)

## Architecture

### Autoload 싱글톤 (project.godot에 등록)
- **GameManager** — 턴제 휘발성 상태 (turn_count, ball_count, current_level). 시그널: `turn_changed`, `ball_count_changed`, `game_over`, `stage_cleared`
- **SaveManager** — `user://save_data.json` 영속 데이터 (해금 레벨, 최저 턴 기록, 별, 볼륨)
- **SoundManager** — BGM/SFX 버스 관리, SFX 풀 5개

### 게임 흐름
```
title_screen → stage_select → turn_game_scene → game_over_menu → stage_select
```

### 턴 루프 상태 머신 (turn_game_scene.gd)
```
AIMING → FIRING → WAITING → TURN_END → AIMING
```
- AIMING: Launcher가 Raycast 기반 점선 가이드(1바운스 미리보기) 표시
- FIRING: 0.05초 간격으로 공 연사
- WAITING: 공 회수 대기. 실시간 5초→2x, 10초→3x 점진적 배속
- TURN_END: 벽돌 하강 → 게임오버/클리어 체크 → 공 아이템 정산

### 충돌 레이어
| Layer | 대상 | 용도 |
|-------|------|------|
| 1 | 벽, 벽돌 | 기본 물리 |
| 2 | 공 | 공끼리 충돌 방지 (mask=1만) |

Floor(Area2D)와 BallItem(Area2D)은 `collision_mask=2`로 공만 감지.

### 화면 레이아웃 (480×854)
```
  0px ┌────────────────────────────┐
      │      TOP HUD (68px)        │
 68px ├════════════════════════════╡ ← 천정벽 (4px, ColorRect)
      ║                            ║
      ║      PLAY AREA (676px)     ║ ← 옆벽 (4px, ColorRect)
      ║                            ║
748px ╠════════════════════════════╣ ← 바닥벽 (4px, ColorRect)
      │   BOTTOM AREA (102px)      │
854px └────────────────────────────┘
```
- 벽 시각: CeilingWall, FloorWall, LeftWall, RightWall (ColorRect, Color(0.3, 0.4, 0.6, 0.8))
- 벽 물리: WallTop(StaticBody2D, Y=58), WallLeft(X=-10), WallRight(X=490)
- GRID_TOP_OFFSET=84, FLOOR_Y=744, Floor Area2D(Y=764)
- GRID_COLS=10, 정사각형 셀 (cell_height = cell_width = 48px)

### 벽돌 시스템 (brick.gd)
- **사각형**: Sprite2D + RectangleShape2D, Kenney 텍스처
- **직각삼각형**: Polygon2D + CollisionPolygon2D, 단색 채움. 4방향 (dir 0:◣ 1:◢ 2:◤ 3:◥)
- HP 구간 색상: Green(1-10), Orange(11-30), Red(31+), Grey(파괴불가 hp=-1)
- HP 라벨 오버레이

### 공 물리 (ball.gd)
- RigidBody2D, bounce=1.0, gravity=0, CCD 활성화
- `_physics_process`에서 매 프레임 속도를 `_target_speed`로 강제 유지
- 충돌 후 `call_deferred`로 각도 보정 (수평 ±15도 차단)
- 멈춘 공은 아래로 밀어서 바닥으로 회수

### 레벨 데이터 (data/levels/level_N.json)
```json
{
  "ball_speed": 400,
  "initial_balls": 50,
  "star_thresholds": [10, 7, 4],
  "bricks": [
    {"row": 0, "col": 3, "hp": 40},
    {"row": 1, "col": 2, "hp": 20, "type": "tri", "dir": 0}
  ],
  "ball_items": [{"row": 1, "col": 1}]
}
```
- `type` 생략 시 사각형, `"tri"`면 삼각형 + `dir` 필수
- `star_thresholds`: [1성 기준턴, 2성 기준턴, 3성 기준턴] (이하면 획득)
- 7열 그리드, 셀 크기는 뷰포트 너비/7로 동적 계산

## Code Conventions

- 모든 주석, 응답, **git 커밋 메시지**는 **한국어**로 작성
- Private: `_snake_case`, Constants: `UPPER_SNAKE_CASE`, Signals: `snake_case`
- Boolean: `is_`, `has_`, `can_` 접두사
- 함수 상단에 목적 주석 필수
- 각 .tscn 씬에 대응하는 .gd 스크립트 1:1 매핑
- Tween 애니메이션은 `create_tween()` 패턴
- 시그널 연결은 `_ready()`에서 수행

## Inactive Files

`game_scene.tscn/gd`, `paddle.tscn/gd`, `power_up.tscn/gd`는 클래식 모드용으로 보존 중이나 현재 GameManager와 호환되지 않음.
