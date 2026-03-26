# Turn-Based Brick Breaker Conversion - Phase 1 Design Spec

## Overview

기존 실시간 패들 벽돌깨기를 Ballz/BBTAN 스타일의 턴제 벽돌깨기로 전환한다.
Phase 1에서는 핵심 메카닉(조준/발사, 턴 진행, 사각형 벽돌, 공 아이템, 스테이지 클리어)만 구현한다.

### Scope

**포함:**
- 턴제 게임 루프 (조준 → 발사 → 대기 → 턴 종료)
- Launcher (조준선 + 연사 발사)
- 사각형 벽돌 (HP 숫자 오버레이, 텍스처 색상 구간)
- 매 턴 벽돌 하강
- 공 아이템 수집
- 턴 수 기반 별 평가
- 5개 레벨 리뉴얼

**제외 (Phase 2):**
- 직각삼각형 벽돌 (4방향, CollisionPolygon2D)
- 무한 서바이벌 모드
- 추가 파워업/아이템 종류

---

## 1. Scene Structure

```
TurnGameScene (Node2D)
├── Walls (StaticBody2D)          # 좌/우/상단 벽
├── Floor (Area2D)                # 바닥 — 공 회수 감지
├── Launcher (Node2D)             # 조준선 + 발사 지점
│   ├── AimLine (Line2D)          # 조준 시 방향 표시 (점선)
│   └── LaunchPoint (Marker2D)    # 공 생성 위치
├── BrickContainer (Node2D)       # 벽돌들
├── BallContainer (Node2D)        # 활성 공들
├── ItemContainer (Node2D)        # 공 아이템들
├── HUD (CanvasLayer)             # 턴 수, 공 개수, 스테이지 표시
├── PauseMenu
└── GameOverMenu
```

### 기존 대비 변경점

| 기존 | 변경 |
|------|------|
| `Paddle` (패들) | `Launcher` (조준선 + 발사 지점) |
| `DeathZone` (공 소멸) | `Floor` (공 회수 + 다음 턴 발사 위치 결정) |
| 실시간 입력 | 턴제 상태 머신 |

---

## 2. Turn Loop & State Machine

### States

| 상태 | 설명 | 플레이어 입력 |
|------|------|--------------|
| `AIMING` | 터치/드래그로 발사 각도 조절, 조준선 표시 | O |
| `FIRING` | 공을 ~0.05초 간격으로 연사 중 | X |
| `WAITING` | 모든 공이 날아다니는 중, 바닥 도달 대기 | X |
| `TURN_END` | 공 회수 완료 → 후처리 → 다음 턴 | X |

### Turn End Sequence

1. 벽돌 전체 한 줄 하강 (Tween ~0.3초)
2. 벽돌이 발사 라인에 도달했는지 체크 → 게임오버
3. 남은 벽돌 0개인지 체크 → 스테이지 클리어
4. 수집한 공 아이템 반영 (공 개수 +N)
5. 턴 카운터 +1
6. 상태 → `AIMING`

---

## 3. Launcher (Aiming & Firing)

### Aiming

- 발사 지점에서 터치/드래그 → 반대 방향으로 조준선 표시 (새총 방식)
- `Line2D`로 점선 표현
- 조준선은 첫 번째 바운스(벽/벽돌 반사) 지점까지 미리보기 (Raycast 사용)
- 발사 각도 제한: 수평 ±10도 이내 차단 (거의 수평 발사 방지)

### Firing

- 터치를 떼면 발사 시작
- `Timer`로 ~0.05초 간격 연사
- 공 개수만큼 같은 각도로 하나씩 생성 후 발사
- 모든 공 발사 완료 → 상태: `WAITING`

### Launch Point Movement

- 첫 턴: 화면 하단 중앙
- 이후: 이전 턴에서 첫 번째로 바닥에 닿은 공의 X 위치

---

## 4. Ball Mechanics

### Physics

- `RigidBody2D`, `gravity_scale = 0`
- 일정 속도 직선 이동, 벽/벽돌에 완전 탄성 반사
- 매 프레임 `linear_velocity`를 고정 속도로 정규화 (속도 보정)

### Floor Collection

- `Floor` Area2D와 충돌 시 공 비활성화
- 첫 번째 공: X 위치 저장 (다음 턴 발사 지점)
- 나머지 공: 바닥 도달 시 첫 번째 공 위치로 Tween 이동 후 소멸
- 모든 공 회수 완료 → `TURN_END`

### Ball Items

- 벽돌 사이 그리드에 배치되는 원형 아이콘 (`Area2D`)
- 공이 접촉 시 즉시 수집 (사라짐)
- 턴 종료 시 수집 개수만큼 공 +N
- 레벨 JSON의 `ball_items` 배열에서 위치 지정

---

## 5. Brick System

### HP & Visuals

- HP 범위: 1~999 (레벨 JSON에서 지정)
- Kenney 텍스처 위에 `Label`로 HP 숫자 오버레이 (중앙 정렬, 외곽선으로 가독성 확보)
- HP 구간별 텍스처 색상:

| HP 범위 | 텍스처 | 의미 |
|---------|--------|------|
| 1~10 | Green | 약함 |
| 11~30 | Orange | 보통 |
| 31+ | Red | 강함 |

- 공 충돌 시 HP -1
- 현재 HP에 따라 텍스처 색상 자동 변경
- HP 0 도달 시 파괴 (파티클 + 소멸)

### Descent

- 턴 종료 시 모든 벽돌이 한 칸(벽돌 높이 + 마진)만큼 아래로 이동
- `Tween`으로 ~0.3초 부드럽게 이동
- 하강 후 벽돌 Y 위치가 발사 라인(Floor) 이상 → 게임오버

### Indestructible Bricks

- `hp = -1`: 회색 텍스처, 숫자 표시 없음
- 공 반사만 되고 파괴 안 됨

---

## 6. Level Data Format

```json
{
  "ball_speed": 400,
  "initial_balls": 1,
  "star_thresholds": [20, 15, 10],
  "bricks": [
    { "row": 0, "col": 0, "hp": 12 },
    { "row": 0, "col": 3, "hp": -1 },
    { "row": 1, "col": 2, "hp": 25 }
  ],
  "ball_items": [
    { "row": 1, "col": 1 },
    { "row": 2, "col": 4 }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `ball_speed` | float | 공 이동 속도 |
| `initial_balls` | int | 시작 공 개수 |
| `star_thresholds` | [int, int, int] | 별 기준 턴 수 [1성, 2성, 3성] — 낮을수록 좋음 |
| `bricks` | Array | 벽돌 배치 (row, col, hp) |
| `ball_items` | Array | 공 아이템 위치 (row, col) |

---

## 7. Integration with Existing Systems

### GameManager 수정

| 기존 | 변경 |
|------|------|
| `score: int` | `turn_count: int` |
| `lives: int` | `ball_count: int` |
| `score_changed` signal | `turn_changed` signal |
| `lives_changed` signal | `ball_count_changed` signal |
| `add_brick_score(hp)` | 제거 (HP -1은 Brick 자체 처리) |
| `lose_life()` | 제거 |
| `clear_stage()` | 턴 수 기반 별 계산으로 변경 |
| `start_level(level)` | `start_level(level, initial_balls)` |

### SaveManager 수정

- 구조 변경 없음
- `complete_stage(level, score, stars)` 유지
- `score` 자리에 턴 수 저장 (낮을수록 좋음)
- `high_scores` 비교: `>` → `<` (최저 턴 기록)
- 첫 플레이 시 기본값 처리 (기존 0 → 999 등)

### SoundManager

- 변경 없음. 발사음, 충돌음, 파괴음 효과음 추가만 필요

### HUD 수정

| 기존 | 변경 |
|------|------|
| Score 표시 | Turn 수 표시 |
| Lives 표시 | Ball 개수 표시 |
| Level 표시 | 유지 |

### GameOverMenu 수정

- 별 표시를 턴 수 기준으로 변경

---

## 8. File Changes Summary

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `scripts/autoload/game_manager.gd` | 턴/공 개수 로직, 시그널 변경 |
| `scripts/autoload/save_manager.gd` | 최저 턴 비교 로직 |
| `scripts/hud.gd` + 씬 | Turn/Ball 표시 |
| `scripts/objects/brick.gd` + 씬 | HP 라벨 추가, 색상 구간 로직, HP -1 처리 |
| `scripts/objects/ball.gd` + 씬 | 속도 정규화, 바닥 회수 로직, 중력 제거 |
| `scripts/game_over_menu.gd` | 턴 수 기반 별 표시 |
| `scripts/stage_select.gd` | 최저 턴 표시 (기존 최고 점수 대신) |
| `data/levels/level_1~5.json` | 턴제용 데이터 리뉴얼 |

### 신규 파일

| 파일 | 역할 |
|------|------|
| `scenes/turn_game_scene.tscn` | 턴제 메인 씬 |
| `scripts/turn_game_scene.gd` | 턴 루프, 상태 머신, 벽돌 하강 |
| `scenes/objects/launcher.tscn` | 조준선 + 발사 지점 씬 |
| `scripts/objects/launcher.gd` | 조준/발사 로직 |
| `scenes/objects/ball_item.tscn` | 공 수집 아이템 씬 |
| `scripts/objects/ball_item.gd` | 공 아이템 수집 로직 |

### 유지 파일 (변경 없음)

| 파일 | 이유 |
|------|------|
| `scripts/autoload/sound_manager.gd` | 효과음 추가만, 구조 변경 없음 |
| `scripts/title_screen.gd` | 그대로 유지 |
| `scripts/settings_popup.gd` | 그대로 유지 |
| `scripts/pause_menu.gd` | 그대로 유지 |

### 비활성 파일 (Phase 1에서 사용 안 함)

| 파일 | 이유 |
|------|------|
| `scenes/game_scene.tscn` | 클래식 모드 복원 가능성을 위해 보존 |
| `scripts/game_scene.gd` | 위와 동일 |
| `scenes/objects/paddle.tscn` | 턴제에서 패들 불필요 |
| `scripts/objects/paddle.gd` | 위와 동일 |
| `scenes/objects/power_up.tscn` | Phase 1에서 파워업 없음 |
| `scripts/objects/power_up.gd` | 위와 동일 |
