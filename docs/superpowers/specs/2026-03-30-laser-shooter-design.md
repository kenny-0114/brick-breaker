# Laser Shooter Item Design

## Overview

그리드에 배치되는 독립 오브젝트. 공이 통과하면 트리거되어 지정된 방향으로 직선 레이저를 발사한다. 경로상 벽돌에 데미지를 주며, 파괴불가 벽돌에 막힌다. 트리거 횟수 제한이 있으며 소진 시 사라진다. 공과 충돌하지 않고 통과만 감지한다.

## Data Structure

### Level JSON

```json
{
  "laser_shooters": [
    {"row": 3, "col": 5, "uses": 20, "damage": 1, "dirs": [0, 2]},
    {"row": 5, "col": 2, "uses": 10, "damage": 3, "dirs": [0, 1, 2, 3]}
  ]
}
```

- `uses`: 트리거 가능 횟수. 0이 되면 슈터 소멸
- `damage`: 레이저 1회 발사 시 경로상 벽돌에 주는 데미지 (기본 1)
- `dirs`: 발사 방향 배열 (0=위, 1=오른쪽, 2=아래, 3=왼쪽)

## Visual

### 슈터 텍스처 자동 선택

`dirs` 개수에 따라 텍스처 자동 선택:

| dirs 개수 | 텍스처 | 회전 |
|-----------|--------|------|
| 1 | `laser_shooter_1dir.png` | dirs[0] 방향으로 회전 |
| 2 | `laser_shooter_2dir.png` | dirs 방향에 맞게 회전 |
| 3~4 | `laser_shooter_4dir.png` | 고정 (회전 없음) |

- uses 잔여 횟수를 슈터 위에 라벨로 표시 (HP 라벨과 동일 스타일)

## Trigger Logic

### 트리거 조건

- `Area2D`로 공 감지 (collision_mask=2, 공만 감지)
- 공이 슈터 영역을 통과하면 트리거 — 공은 반사 없이 그대로 통과
- 트리거 시 `uses -= 1`
- `uses`가 0이 되면 슈터 소멸

### 레이저 발사

트리거 즉시, 각 `dirs` 방향으로 동시에 레이저 발사:

1. 슈터 위치에서 해당 방향으로 직선 탐색
2. 경로상 벽돌에 `damage`만큼 데미지 (`hit()` 반복 호출)
3. 파괴불가 벽돌(hp=-1)에 도달하면 해당 벽돌에서 멈춤 (관통 불가, 뒤쪽 무시)
4. 벽이나 화면 끝에 도달하면 멈춤
5. 점수/콤보 동일 적용

### 벽돌 하강

- 슈터도 벽돌과 함께 매 턴 한 칸 하강
- `turn_game_scene`의 `_descend_bricks()`에서 슈터 컨테이너도 함께 처리
- 슈터가 바닥 라인에 도달하면 게임오버 판정에는 영향 없음 (벽돌만 판정)

## Animation

### 레이저 빔 연출

```
0.0s  공이 슈터 통과 (트리거)
0.0s  각 방향으로 레이저 빔 즉시 표시
      — 빔 길이: 슈터 위치 ~ 파괴불가 벽돌/벽까지
      — 경로상 벽돌에 damage 적용 + 점수 팝업
0.1s  빔 밝기 최대 (번쩍)
0.2s  빔 페이드아웃 → 소멸
```

- `laser.png`를 방향에 맞게 회전 + 길이에 맞게 y스케일
- 번쩍 효과: `modulate`를 흰색으로 올렸다가 페이드아웃

### 슈터 소멸 연출

- uses가 0이 되면 축소 + 페이드아웃 (0.3초)
- Tween: `scale` 1.0 → 0.5 + `modulate:a` 1.0 → 0.0

## Architecture

### 파일 구조

```
scripts/objects/
  laser_shooter.gd    — (신규) 슈터 로직, 트리거 감지, 레이저 발사
  laser_beam.gd       — (신규) 레이저 빔 연출, 데미지 적용, 자동 소멸

scenes/objects/
  laser_shooter.tscn  — (신규) Area2D + Sprite2D + UsesLabel
  laser_beam.tscn     — (신규) Sprite2D (laser.png)

scripts/
  turn_game_scene.gd  — 슈터 컨테이너 추가, _load_level에서 슈터 배치, 하강 처리
```

### laser_shooter.gd

```
extends Area2D

- Sprite2D: 방향 수에 따라 텍스처 자동 선택 + 회전
- UsesLabel: 잔여 횟수 표시
- uses, damage, dirs 속성
- 공 통과 감지 → _on_body_entered → 레이저 발사 → uses 감소
- uses == 0 → 소멸 연출
```

### laser_beam.gd

```
extends Node2D

- Sprite2D: laser.png, 방향 회전, y스케일로 길이 조절
- setup(origin, direction, max_length, damage)
- 경로상 벽돌 탐색 → 데미지 적용
- 번쩍 + 페이드아웃 → queue_free
```

### turn_game_scene.gd 변경

- `ShooterContainer` 노드 추가
- `_load_level()`에서 `laser_shooters` 배열 파싱 + 슈터 배치
- `_descend_bricks()`에서 슈터도 함께 하강
- 슈터가 벽돌 파괴 시 `_remaining_bricks` 감소 + 점수/콤보 처리

## Asset Summary

| 용도 | 파일 경로 |
|------|----------|
| 레이저 빔 | `kenney-assets/kenney_rolling-ball-assets/PNG/Retina/laser.png` → `assets/images/items/missile/laser.png`로 복사 |
| 슈터 1방향 | `assets/images/items/missile/laser_shooter_1dir.png` |
| 슈터 2방향 | `assets/images/items/missile/laser_shooter_2dir.png` |
| 슈터 4방향 | `assets/images/items/missile/laser_shooter_4dir.png` |

## Scope

### 포함

- 레이저 슈터 씬 및 스크립트
- 레이저 빔 씬 및 스크립트
- 레벨 JSON 파싱 및 배치
- 방향별 텍스처 자동 선택 + 회전
- 트리거/발사/데미지/소멸 로직
- 빔 연출 (번쩍 + 페이드아웃)
- 하강 처리
- 레벨 에디터에 슈터 도구 추가
- 테스트 레벨에 슈터 배치

### 미포함

- 사운드 이펙트 (추후)
- 레이저끼리 상호작용 (추후)
