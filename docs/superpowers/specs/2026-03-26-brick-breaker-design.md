# Brick Breaker - Game Design Spec

## Overview

Godot 4.6 기반 모바일(Android) 벽돌깨기 게임. 포트폴리오 및 엔진 학습 목적.
별도 이미지 에셋 제작 없이 Kenney Puzzle Pack 2 + UI Pack을 활용하여 그래픽 구성.

## Screen Flow

```
TitleScreen → StageSelect → GameScene
     ↑            ↑              │
     └────────────┴──── (뒤로/게임오버)
```

- **TitleScreen**: 게임 타이틀, Play 버튼, Settings 버튼
- **StageSelect**: 5개 스테이지 그리드(해금/잠금), Endless Mode 자리(추후 확장)
- **GameScene**: 실제 게임 플레이 화면

씬 전환은 `SceneTree.change_scene_to_file()`로 처리.

## Core Game Rules

- 공을 패들로 튕겨서 벽돌 파괴
- 공이 바닥(DeathZone)에 떨어지면 라이프 -1
- 라이프 0 → 게임오버
- 파괴 가능한 벽돌 전부 파괴 → 스테이지 클리어
- 스테이지 클리어 방식 (레벨 1~5)
- 레벨 데이터는 JSON으로 관리

## Scene Structure

### TitleScreen (`title_screen.tscn`)

```
TitleScreen (Control)
├── Background
├── TitleLabel          # "Brick Breaker"
├── PlayButton          # → StageSelect
├── SettingsButton      # → SettingsPopup
└── SettingsPopup       # BGM/SFX 볼륨 조절
```

### StageSelect (`stage_select.tscn`)

```
StageSelect (Control)
├── Background
├── HeaderLabel         # "Stage Select"
├── StageGrid           # GridContainer
│   ├── StageButton 1~5  # 잠금/해금 + 별 표시
│   └── (추후) EndlessButton
└── BackButton          # → TitleScreen
```

- `unlocked_level`까지만 버튼 활성화
- 클리어한 스테이지에 별 표시 (남은 라이프 = 별 개수)

### GameScene (`game_scene.tscn`)

```
GameScene (Node2D)
├── Background          # TextureRect - BackTile 타일링
├── Walls               # StaticBody2D - 좌/우/상 벽
├── DeathZone           # Area2D - 하단 공 떨어짐 감지
├── Paddle              # AnimatableBody2D - 터치 조작
├── Ball                # RigidBody2D - 물리 기반 공
├── BrickContainer      # Node2D - 벽돌들의 부모 (JSON에서 동적 생성)
├── ItemContainer       # Node2D - 드롭 아이템들의 부모
├── HUD                 # CanvasLayer
│   ├── ScoreLabel
│   ├── LivesDisplay
│   ├── LevelLabel
│   └── PauseButton
├── PauseMenu           # CanvasLayer - 일시정지 (재개/설정/스테이지선택)
└── GameOverMenu        # CanvasLayer - 게임오버/클리어 (재시작/스테이지선택)
```

### SettingsPopup (`settings_popup.tscn`)

```
SettingsPopup (PopupPanel)
├── PanelBG             # NinePatchRect - input_rectangle.png
├── TitleLabel          # "Settings"
├── BGMSlider           # HSlider + Label
├── SFXSlider           # HSlider + Label
└── CloseButton
```

- TitleScreen과 PauseMenu 양쪽에서 접근 가능

## Game Mechanics

### Ball

- **Node**: `RigidBody2D` + `CircleShape2D`
- **Physics**: `PhysicsMaterial` bounce=1.0, friction=0.0, gravity_scale=0
- **Behavior**:
  - 게임 시작 시 패들 위에 붙어있다가 터치하면 발사 (45도 부근 랜덤 각도)
  - 최소/최대 속도 클램핑으로 극단적 속도 방지
  - 수평/수직에 가까운 각도 보정 (무한 반복 방지)

### Paddle

- **Node**: `AnimatableBody2D` + `CollisionShape2D`
- **Input**: 터치/드래그로 X축 이동 (화면 밖 클램핑)
- **반사각 조정**: 공이 패들 어디를 맞느냐에 따라 반사각 변화
  - 왼쪽 끝 → 왼쪽으로 더 꺾임
  - 중앙 → 수직에 가깝게
  - 오른쪽 끝 → 오른쪽으로 더 꺾임

### Brick

- **Node**: `StaticBody2D` + `CollisionShape2D`
- **HP System** (3단계):
  - 1HP → `tileGreen_14.png` (초록)
  - 2HP → `tileOrange_14.png` (주황)
  - 3HP → `tileRed_14.png` (빨강)
- **파괴불가 벽돌**: `tileGrey_14.png` (회색), 충돌은 하되 HP 감소 없음
- **파괴 시**: 파티클 이펙트 + 점수 추가 + 확률적 아이템 드롭

### PowerUp Items

- **Drop**: 벽돌 파괴 시 20% 확률로 생성
- **Node**: `Area2D` + 중력으로 자연 낙하
- **수집**: 패들 접촉 시 효과 발동, DeathZone 도달 시 소멸

| 종류 | 효과 | 지속시간 | 중복 획득 | 시각적 구분 |
|------|------|----------|-----------|-------------|
| 패들 확장 | 패들 가로 크기 1.5배 | 10초 | 타이머 리셋 | `coin_01.png` + 녹색 tint |
| 멀티볼 | 현재 공 기준 ±30도로 2개 추가 생성 | 추가 공 모두 소멸 시까지 | 추가 생성 | `coin_01.png` + 파란 tint |

- 패들 확장 종료 시 Tween으로 부드럽게 원복
- 멀티볼 시 공이 전부 DeathZone에 빠져야 라이프 감소

## Score System

| 항목 | 점수 |
|------|------|
| 1HP 벽돌 파괴 | 100점 |
| 2HP 벽돌 파괴 | 200점 |
| 3HP 벽돌 파괴 | 300점 |
| 스테이지 클리어 보너스 | 남은 라이프 × 500점 |

- HUD에 실시간 표시
- 스테이지별 최고 점수 저장

## Star System

- **기준**: 스테이지 클리어 시 남은 라이프 수 = 별 개수 (최대 3개)
- **표시**: StageSelect 화면에서 각 스테이지 버튼 아래에 별 아이콘
- **리소스**: `star.png` (획득), `star_outline.png` (미획득) from kenney_ui-pack Yellow

## Level Data

### JSON Structure

```json
{
  "level": 1,
  "lives": 3,
  "ball_speed": 300,
  "bricks": [
    { "row": 0, "col": 0, "hp": 1 },
    { "row": 0, "col": 1, "hp": 2 },
    { "row": 1, "col": 3, "hp": -1 }
  ]
}
```

- `hp`: 1/2/3 = 일반 벽돌, `-1` = 파괴불가 벽돌
- `lives`: 모든 레벨 고정 3. JSON에 명시하되 값은 항상 3
- `row`/`col`: 그리드 좌표 → 타일 크기 기반으로 실제 위치 계산
- 파일 위치: `res://data/levels/level_1.json` ~ `level_5.json`

### Level Difficulty Curve

| 레벨 | 벽돌 구성 | ball_speed | 특징 |
|------|-----------|-----------|------|
| 1 | 1HP 위주 | 250 | 튜토리얼, 조작 익히기 |
| 2 | 1HP + 2HP 혼합 | 300 | HP 개념 학습 |
| 3 | 1~3HP + 파괴불가 등장 | 300 | 장애물 개념 도입 |
| 4 | 2~3HP 위주 + 파괴불가 | 370 | 본격 난이도 |
| 5 | 3HP + 파괴불가 복합 | 400 | 최종 스테이지 |

## Save System

저장 위치: `user://save_data.json`

```json
{
  "unlocked_level": 3,
  "high_scores": { "1": 2400, "2": 1800 },
  "stars": { "1": 3, "2": 2, "3": 1 },
  "settings": { "bgm_volume": 0.8, "sfx_volume": 1.0 }
}
```

## Autoload Singletons

| 이름 | 역할 |
|------|------|
| **GameManager** | 플레이 중 휘발성 상태 (점수, 라이프, 현재 레벨, 파워업 상태). 씬 전환 시에도 유지 |
| **SaveManager** | 영속 데이터 읽기/쓰기 (해금 레벨, 최고점수, 별, 설정값) |
| **SoundManager** | BGM/SFX 재생 및 볼륨 제어. AudioStreamPlayer 풀 관리 |

### SoundManager Structure

```
SoundManager (Node) — 오토로드
├── BGMPlayer           # AudioStreamPlayer - 배경음악 (루프)
├── SFXPool             # AudioStreamPlayer x 4~5개 - 동시 다발 SFX
```

- BGM/SFX 버스 분리: `AudioServer.set_bus_volume_db()`로 제어
- 볼륨 값은 SaveManager에 저장 → 앱 재시작 시 복원

## Project File Structure

```
res://
├── assets/
│   ├── images/
│   │   ├── bricks/          # tileGreen_14, tileOrange_14, tileRed_14, tileGrey_14
│   │   ├── ball/            # ballBlue_01
│   │   ├── paddle/          # paddle_04
│   │   ├── particles/       # particleWhite_1~7
│   │   ├── items/           # coin_01
│   │   ├── background/      # BackTile_01
│   │   └── ui/              # button, icon, input_rectangle, divider, star, star_outline
│   ├── fonts/               # Kenney Future, Kenney Future Narrow
│   └── sounds/              # click-a, tap-a
├── data/
│   └── levels/              # level_1.json ~ level_5.json
├── scenes/
│   ├── title_screen.tscn
│   ├── stage_select.tscn
│   ├── game_scene.tscn
│   ├── objects/
│   │   ├── ball.tscn
│   │   ├── brick.tscn
│   │   ├── paddle.tscn
│   │   └── power_up.tscn
│   └── ui/
│       └── settings_popup.tscn
├── scripts/
│   ├── title_screen.gd
│   ├── stage_select.gd
│   ├── game_scene.gd
│   ├── objects/
│   │   ├── ball.gd
│   │   ├── brick.gd
│   │   ├── paddle.gd
│   │   └── power_up.gd
│   └── autoload/
│       ├── game_manager.gd
│       ├── save_manager.gd
│       └── sound_manager.gd
└── project.godot
```

## Resource Mapping

### kenney_puzzle-pack-2

| 용도 | 파일 |
|------|------|
| 벽돌 1HP | `PNG/Tiles green/tileGreen_14.png` |
| 벽돌 2HP | `PNG/Tiles orange/tileOrange_14.png` |
| 벽돌 3HP | `PNG/Tiles red/tileRed_14.png` |
| 파괴불가 벽돌 | `PNG/Tiles grey/tileGrey_14.png` |
| 패들 | `PNG/Paddles/paddle_04.png` |
| 공 | `PNG/Balls/Blue/ballBlue_01.png` |
| 파티클 | `PNG/Particles white/particleWhite_1~7.png` |
| 파워업 아이템 | `PNG/Coins/coin_01.png` |
| 배경타일 | `PNG/Back tiles/BackTile_01.png` |

### kenney_ui-pack

| 용도 | 파일 |
|------|------|
| 획득 별 | `PNG/Yellow/Default/star.png` |
| 미획득 별 | `PNG/Yellow/Default/star_outline.png` |
| UI 패널 배경 | `PNG/Extra/Default/input_rectangle.png` |
| 메뉴 버튼 | `PNG/Blue/Default/button_rectangle_depth_flat.png` |
| 플레이 아이콘 | `PNG/Extra/Default/icon_play_dark.png` |
| 재시작 아이콘 | `PNG/Extra/Default/icon_repeat_dark.png` |
| 구분선 | `PNG/Extra/Default/divider.png` |
| 메인 폰트 | `Font/Kenney Future.ttf` |
| 숫자 폰트 | `Font/Kenney Future Narrow.ttf` |
| UI 클릭 | `Sounds/click-a.ogg` |
| UI 탭 | `Sounds/tap-a.ogg` |

> **Note:** 게임 SFX(공 반사, 벽돌 파괴, 아이템 획득, 게임오버)와 BGM은 리소스팩에 포함되어 있지 않음. 추후 무료 에셋 추가 또는 Godot AudioStreamGenerator로 간단한 효과음 생성 예정.

## Implementation Approach

- **물리 기반**: 공은 `RigidBody2D` + `PhysicsMaterial`(bounce=1.0)로 반사/충돌 자동 처리
- 패들은 `AnimatableBody2D`로 터치 입력 반응
- 벽돌은 `StaticBody2D`로 충돌 감지 후 HP 관리
- Godot 물리 엔진이 반사각/충돌을 처리하고, 패들 타격 위치에 따른 반사각 보정만 추가

## Future Expansion (Not in Current Scope)

- Endless Mode (무한 점수 모드)
- 추가 레벨 (JSON 추가만으로 확장 가능)
- 폭탄 벽돌 등 특수 벽돌 추가
- 추가 파워업 (공 속도 감소, 레이저 등)
- BGM 에셋 추가
