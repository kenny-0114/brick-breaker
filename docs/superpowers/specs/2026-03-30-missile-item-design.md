# Missile Item Design

## Overview

턴제 벽돌깨기 게임에 **미사일 아이템** 시스템을 추가한다. 미사일 속성이 내장된 특수 벽돌을 파괴하면, 필드 위 랜덤 벽돌 5개에 미사일이 락온되어 HP에 관계없이 즉시 파괴한다. 연출은 게임 진행과 비동기로 동작하여 공은 멈추지 않는다.

## Data Structure

### Level JSON 확장

기존 벽돌 데이터에 `"item"` 속성을 추가한다. 별도 배열이나 씬 없이 벽돌 자체에 아이템을 내장한다.

```json
{
  "bricks": [
    {"row": 2, "col": 4, "hp": 20, "item": "missile"},
    {"row": 0, "col": 3, "hp": 40}
  ]
}
```

- `"item"` 생략 시 일반 벽돌
- `"item": "missile"` → 미사일 아이템 내장 벽돌
- 삼각형 벽돌(`"type": "tri"`)에도 적용 가능

## Item Box Visual (Design C)

미사일 벽돌은 일반 벽돌과 다른 **아이템 상자** 외형으로 표시한다.

### 구조 (Godot 구현 시)

아이템 상자는 벽돌과 동일한 셀 크기(48x48)로, 다음 레이어로 구성:

1. **금속 프레임** — 두꺼운 회색 테두리, 상단 하이라이트 / 하단 그림자
2. **나사 슬롯** — 4개 코너에 일자 나사 장식
3. **유리 패널** — 블루 반투명 유리, 좌상단 광택 반사
4. **미사일 아이콘** — `spaceMissiles_007.png` (X2), 45도 기울여서 유리 안에 표시
5. **HP 텍스트** — 중앙 또는 하단에 표시

### Godot 구현 방식

- `Polygon2D` 또는 `Sprite2D`를 조합하여 프레임/유리/나사를 렌더링
- 또는 SVG를 PNG로 export하여 텍스처로 사용
- 미사일 아이콘은 별도 `Sprite2D` 자식 노드로 45도 rotation

### 참고 목업

- `mockup/item_box_final.html` — 최종 아이템 상자 SVG + 게임 그리드 미리보기
- `mockup/missile_item_mockup.html` — 전체 미사일 시퀀스 애니메이션 목업

## Trigger Logic

### 발동 조건

미사일 벽돌의 HP가 0이 되어 파괴될 때 발동한다. 일반 벽돌과 동일하게 공에 맞아 HP를 깎아야 한다.

### 발동 흐름

1. 미사일 벽돌 파괴 → `brick_destroyed` 시그널 발생
2. `turn_game_scene._on_brick_destroyed()`에서 해당 벽돌의 `item == "missile"` 확인
3. `_activate_missile(position)` 호출

### 타겟 선정

- `brick_container`에서 파괴 가능한 벽돌(`hp > 0`, `hp != -1`) 중 랜덤 5개 선택
- 파괴 가능한 벽돌이 5개 미만이면 있는 만큼만 선택
- 미사일 벽돌 자신은 이미 파괴되었으므로 대상에서 자동 제외

### 비동기 처리

- 미사일 연출은 `await` 하지 않음 — 공은 계속 날아다님
- 미사일이 파괴한 벽돌도 `_remaining_bricks` 감소 처리
- 미사일 파괴로 `_remaining_bricks <= 0`이 되면 클리어 체크 발동
- 미사일 파괴에도 점수 + 콤보 동일 적용

### Edge Case: 타겟이 먼저 파괴됨

미사일이 날아가는 동안 타겟 벽돌이 공에 의해 먼저 파괴되면, 미사일은 빈 자리에 도착하여 그냥 소멸한다 (허공에서 사라짐).

## Animation Sequence

### Timeline

```
0.0s   미사일 벽돌 파괴 (일반 파괴 이펙트 + 점수)
0.0s   타겟 5개 선정 + 락온 마커(crosshair) 표시 (스케일 펀치)
0.1s   1번 미사일 발사 (연기 트레일 동반)
0.15s  2번 미사일 발사
0.2s   3번 미사일 발사
0.25s  4번 미사일 발사
0.3s   5번 미사일 발사 (0.05초 간격)
~0.5s  각 미사일 도착 → 벽돌 즉시 파괴 + 폭발 이펙트 + 점수 팝업
~0.8s  모든 이펙트 자동 소멸
```

게임 진행과 완전히 비동기. 공은 멈추지 않는다.

### Lock-on Marker

- **리소스**: `kenney-res/crosshair_red_large.png`
- 타겟 벽돌 위에 표시, 회전 애니메이션
- 스케일 펀치로 등장 (0 → 1.0, 0.15초)
- 미사일 도착 시 제거

### Missile Flight

- **리소스**: `kenney_space-shooter-extension/PNG/Sprites X2/Missiles/spaceMissiles_007.png`
- 발사 위치: 미사일 벽돌이 파괴된 위치
- `Node2D` 기반 (물리 불필요, 순수 연출)
- `Tween`으로 발사 위치 → 타겟 위치까지 직선 이동 (0.3~0.4초)
- 타겟 방향으로 회전 (look_at)
- 5개 미사일은 0.05초 간격으로 순차 발사

### Smoke Trail

- **리소스**: `kenney_space-shooter-extension/PNG/Sprites/Effects/spaceEffects_009.png`
- `GPUParticles2D`를 미사일 자식 노드로 부착
- 흰~회색 연기, lifetime 0.3초, 뒤쪽으로 방출

### Explosion

- **리소스**: `kenney-res/explosion1.png`, `explosion2.png`, `explosion3.png`
- 3장 순차 표시로 폭발 애니메이션 (프레임 기반)
- 또는 `AnimatedSprite2D`로 3프레임 재생
- 기존 `_spawn_particles`보다 강화된 이펙트

## Architecture

### 파일 구조

```
scripts/objects/
  brick.gd          — item 속성 추가
  missile.gd         — (신규) 미사일 비행 + 이펙트 노드

scenes/objects/
  missile.tscn       — (신규) 미사일 씬

scripts/
  turn_game_scene.gd — 미사일 발동 로직 추가
```

### brick.gd 변경

```
var item: String = ""     # 아이템 속성 ("missile" 등)
```

- `setup()` / `setup_triangle()`에서 item 값 저장
- item이 있으면 일반 벽돌 대신 아이템 상자 외형으로 렌더링
- `brick_destroyed` 시그널은 기존과 동일하게 발생

### missile.gd (신규)

```
extends Node2D

- 미사일 Sprite2D (spaceMissiles_007)
- 연기 GPUParticles2D (spaceEffects_009)
- Tween으로 타겟까지 비행
- 도착 시 타겟 벽돌 즉시 파괴 + 폭발 이펙트 + 자동 소멸
```

### turn_game_scene.gd 변경

- `_on_brick_destroyed()` 에서 item 체크 후 미사일 발동
- `_activate_missile(pos: Vector2)` 함수 추가
  - 타겟 선정
  - 락온 마커 표시
  - 미사일 인스턴스 5개 생성, 0.05초 간격 발사
- 미사일이 벽돌 파괴 시 `_remaining_bricks` 감소 + 점수/콤보 처리

### _load_level() 변경

```gdscript
# 벽돌 배치 시 item 속성 전달
var item_type: String = str(brick_data.get("item", ""))
if item_type != "":
    brick.item = item_type
    # 아이템 상자 외형으로 렌더링
```

## Asset Summary

| 용도 | 파일 경로 | 비고 |
|------|----------|------|
| 미사일 (비행 + 아이콘) | `kenney_space-shooter-extension/PNG/Sprites X2/Missiles/spaceMissiles_007.png` | 비행 시 타겟 방향 회전, 아이콘은 45도 |
| 락온 마커 | `kenney-res/crosshair_red_large.png` | 회전 애니메이션 |
| 폭발 1 | `kenney-res/explosion1.png` | 3장 순차 재생 |
| 폭발 2 | `kenney-res/explosion2.png` | |
| 폭발 3 | `kenney-res/explosion3.png` | |
| 연기 트레일 | `kenney_space-shooter-extension/PNG/Sprites/Effects/spaceEffects_009.png` | GPUParticles2D 텍스처 |

## Scope

### 포함

- 미사일 벽돌 데이터 구조 및 레벨 JSON 파싱
- 아이템 상자 외형 렌더링 (Design C)
- 미사일 발동 로직 (타겟 선정, 비동기 처리)
- 락온 마커 + 미사일 비행 + 연기 트레일 + 폭발 이펙트
- 점수/콤보 적용
- 기존 레벨 1개에 미사일 벽돌 배치 (테스트용)

### 미포함

- 레벨 에디터에서 미사일 벽돌 배치 UI (추후)
- 다른 아이템 타입 (추후 확장 가능한 구조만 마련)
- 사운드 이펙트 (추후)
