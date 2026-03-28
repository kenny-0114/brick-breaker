# Level Editor Design Spec

## Overview

Godot 벽돌깨기 게임의 스테이지 레벨 데이터(JSON)를 시각적으로 편집하는 웹 기반 도구.
단일 HTML 파일로 구현하며, 브라우저에서 바로 실행 가능하다.

- 파일: `mockup/level_editor.html`
- 대상: `data/levels/level_N.json`
- 실행: Chrome에서 더블클릭 (File System Access API 필요)

## Game Constraints

| 항목 | 값 |
|------|-----|
| 그리드 | 10열 (cols 0-9), 정사각형 셀 |
| 최대 행 | 13행 (rows 0-12) |
| 뷰포트 | 480x854, 플레이 영역 Y=74~744 |
| 벽돌 타입 | 사각형 (기본), 삼각형 (`type: "tri"`, `dir: 0~3`) |
| 삼각형 방향 | 0:◣ 1:◢ 2:◤ 3:◥ |
| HP | 양수=파괴가능, -1=파괴불가 |
| HP 색상 | 초록(1-10), 주황(11-30), 빨강(31+), 회색(-1) |
| 볼 아이템 | `ball_items` 배열, row/col만 |

## JSON Schema

```json
{
  "ball_speed": number,
  "initial_balls": number,
  "star_thresholds": [number, number, number],
  "bricks": [
    {"row": number, "col": number, "hp": number},
    {"row": number, "col": number, "hp": number, "type": "tri", "dir": number}
  ],
  "ball_items": [
    {"row": number, "col": number}
  ]
}
```

## Screen Layout

```
┌─────────────────────────────────────────────────────────┐
│  [Open Folder] [Stage ▼] [+ New] [Save] [Delete]       │
├────────┬──────────────────────────┬─────────────────────┤
│ TOOLS  │                          │   PROPERTIES        │
│        │                          │                     │
│ □ Rect │     10 x 13 Grid        │  ball_speed: [400]  │
│ △ Tri  │     (Canvas)             │  initial_balls:[50] │
│ ⊕ Ball │                          │  star: [10] [7] [4] │
│ ✕ Erase│   클릭으로 배치/선택      │                     │
│        │   드래그로 연속 배치       │  ── Selected ──     │
│ HP:[10]│                          │  Type: Rect         │
│ [-][+] │                          │  HP: [20] [-][+]    │
│        │                          │  Dir: [◣][◢][◤][◥] │
│ Dir:   │                          │                     │
│[◣◢◤◥] │                          │  [Delete Cell]      │
├────────┴──────────────────────────┴─────────────────────┤
│  ▶ JSON Preview (토글, 읽기 전용)                        │
└─────────────────────────────────────────────────────────┘
```

- 상단 바: 폴더 열기, 스테이지 드롭다운, 새 스테이지, 저장, 삭제
- 좌측 (120px): 도구 선택, HP 입력, 삼각형 방향 버튼
- 중앙 (유동): Canvas 기반 10x13 그리드
- 우측 (180px): 스테이지 전역 설정 + 선택된 셀 속성
- 하단 (토글): JSON 실시간 미리보기

## Tools Panel

### 도구 목록
| 도구 | 동작 |
|------|------|
| Rect (□) | 빈 셀 클릭 → 사각형 벽돌 배치 (현재 HP) |
| Tri (△) | 빈 셀 클릭 → 삼각형 벽돌 배치 (현재 HP + 방향) |
| Ball (⊕) | 빈 셀 클릭 → 볼 아이템 배치 |
| Eraser (✕) | 내용 있는 셀 클릭 → 삭제 |

### HP 입력
- 숫자 입력란 + [-][+] 버튼 (1 단위)
- Shift+클릭 시 ±10 단위
- -1 버튼 (INF 파괴불가 토글)
- 배치 시 이 HP 값이 적용됨

### 삼각형 방향
- 4개 버튼: ◣(0) ◢(1) ◤(2) ◥(3)
- Tri 도구 선택 시에만 활성화
- 배치 전 방향 설정, 배치 후에도 우측 패널에서 변경 가능

## Grid Interaction

### Canvas 렌더링
- `<canvas>` 요소에 직접 그리기
- 셀 크기: canvas 폭 / 10 (정사각형)
- 배경: 어두운 색 + 연한 격자선

### 셀 표현
| 타입 | 시각 표현 |
|------|----------|
| 사각형 벽돌 | HP 색상 채움 + 흰색 HP 숫자 |
| 삼각형 벽돌 | 방향에 맞는 삼각형 path + HP 색상 + HP 숫자 |
| 볼 아이템 | 초록 원 + "+" 텍스트 |
| 빈 셀 | 투명 + 격자선만 |
| 선택된 셀 | 파란 테두리 (2px) |

### HP 색상 매핑
```
HP 1-10:   #8bc34a (초록)
HP 11-30:  #f5a623 (주황)
HP 31+:    #e74c3c (빨강)
HP -1:     #8a8a95 (회색)
```

### 마우스 이벤트
- mousedown → 도구에 따라 배치/선택/삭제 + 드래그 시작
- mousemove (드래그 중) → 연속 배치/삭제
- mouseup → 드래그 종료
- 이미 내용 있는 셀에 Rect/Tri/Ball 도구 클릭 → 해당 셀 선택 (덮어쓰지 않음)

## Properties Panel

### 스테이지 전역 설정 (항상 표시)
- `ball_speed`: 숫자 입력 (기본 400)
- `initial_balls`: 숫자 입력 (기본 50)
- `star_thresholds`: 3개 숫자 입력 [1성, 2성, 3성]

### 선택된 셀 속성 (셀 선택 시 표시)
- Type 표시: "Rect" / "Tri" / "Ball Item"
- HP: 숫자 입력 + [-][+] (벽돌만)
- Dir: 방향 버튼 4개 (삼각형만)
- [Delete] 버튼: 선택된 셀 내용 삭제

## File I/O

### File System Access API (Chrome)
```javascript
// 폴더 열기
const dirHandle = await window.showDirectoryPicker();

// 파일 읽기
const fileHandle = await dirHandle.getFileHandle('level_1.json');
const file = await fileHandle.getFile();
const text = await file.text();

// 파일 쓰기
const writable = await fileHandle.createWritable();
await writable.write(JSON.stringify(data, null, 2));
await writable.close();
```

### 스테이지 관리
| 동작 | 설명 |
|------|------|
| Open Folder | `data/levels/` 폴더 선택, `level_*.json` 스캔 |
| Stage 드롭다운 | 파일 전환, 미저장 시 확인 다이얼로그 |
| + New | 빈 레벨 생성 (기본값), `level_N.json` (N=최대+1) |
| Save | 현재 파일에 덮어쓰기 |
| Delete | 확인 후 파일 삭제, 다음 스테이지로 전환 |

### 변경 감지
- 편집 시 dirty 플래그 설정
- 스테이지 전환 시 미저장 경고
- 저장 완료 시 "Saved!" 토스트 메시지 (2초)

## Grid ↔ JSON 변환

### Grid → JSON (저장 시)
```
grid[row][col] 2D 배열 순회:
  - null → 스킵
  - {type:"rect", hp:N} → bricks에 추가
  - {type:"tri", hp:N, dir:D} → bricks에 type, dir 포함하여 추가
  - {type:"ball"} → ball_items에 추가
정렬: row → col 순서
```

### JSON → Grid (로드 시)
```
13x10 null 배열 초기화
bricks 순회: grid[row][col] = {type, hp, dir?}
ball_items 순회: grid[row][col] = {type:"ball"}
```

## Tech Stack

- 단일 HTML 파일 (`mockup/level_editor.html`)
- Vanilla JS (프레임워크 없음)
- Canvas API (그리드 렌더링)
- File System Access API (파일 I/O, Chrome 전용)
- CSS 다크 테마 (게임과 유사한 색감)

## Non-Goals

- 모바일 지원 (데스크톱 Chrome 전용)
- 실시간 게임 미리보기 (JSON 편집만)
- 언두/리두 (v1 범위 외)
- 멀티 유저 동시 편집
