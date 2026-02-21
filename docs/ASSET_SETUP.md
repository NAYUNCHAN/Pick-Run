# Pick&Run Asset Setup (Godot 4.6)

이 문서는 Pick&Run에서 에셋을 교체/추가할 때 필요한 기본 규칙과 Godot 4.6 임포트 설정을 정리합니다.

## 1) 폴더 구조와 파일 배치

아래 경로를 사용합니다.

- 말 스프라이트: `res://assets/sprites/horses/`
- 트랙 스프라이트: `res://assets/sprites/track/`
- UI 이미지: `res://assets/ui/`
- 효과음: `res://assets/sfx/`
- 배경음: `res://assets/bgm/`

권장 파일명 규칙(소문자+스네이크/로마자):

- `res://assets/sprites/horses/kongkong.png`
- `res://assets/sprites/horses/mallang.png`
- `res://assets/sprites/horses/dugeun.png`
- `res://assets/sprites/horses/banjjak.png`
- `res://assets/sprites/track/track_bg.png`

`HorseData.gd`의 `texture_path`와 파일명을 맞춰야 자동 로드됩니다.

---

## 2) Godot 4.6 픽셀 아트 임포트 설정

픽셀 아트 기반 이미지를 쓰는 경우 각 텍스처를 선택한 뒤 Import 탭에서 아래 설정을 권장합니다.

- **Filter**: Off
- **Mipmaps**: Off
- **Compression Mode**: Lossless (또는 품질 저하 없는 설정)
- 필요 시 Repeat: Disabled

설정 변경 후 반드시 **Reimport** 버튼을 눌러 반영합니다.

---

## 3) Reimport / 반영 절차

1. 에셋 파일을 위 폴더에 복사
2. Godot 에디터에서 파일 선택
3. Import 탭 설정 확인/수정
4. **Reimport** 클릭
5. 실행(Play) 후 레이스/메뉴 화면에서 시각 반영 확인

---

## 4) 에셋이 없어도 동작하는 fallback 구조

현재 프로젝트는 에셋이 없어도 크래시 없이 동작합니다.

- 말 이미지(`texture_path`)가 없으면:
  - `Horse.gd`에서 `ResourceLoader.exists(path)` 확인 실패 시 `Sprite2D`를 숨기고 `Body(ColorRect)` 플레이스홀더를 표시합니다.
- 트랙 배경 이미지(`res://assets/sprites/track/track_bg.png`)가 없으면:
  - `RaceController.gd`가 `TrackBgSprite`를 숨기고 `TrackBg(ColorRect)`를 유지합니다.

즉, 에셋 파일이 없는 상태에서도 플레이 가능하며, 파일을 추가하면 자동으로 실제 텍스처를 사용합니다.
