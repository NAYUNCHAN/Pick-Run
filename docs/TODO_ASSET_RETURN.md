# TODO: 에셋 재적용 포인트

현재 빌드는 외부 에셋(이미지/텍스처)을 완전히 비활성화한 상태입니다.

## 나중에 에셋을 다시 붙일 위치

1. `scenes/entities/Horse.tscn`
   - 현재 `ColorRect` 기반 플레이스홀더 마필 구조입니다.
   - `Sprite2D`를 다시 추가하고, 번호/이름 라벨과 레이어 순서를 조정합니다.

2. `scripts/Horse.gd`
   - `setup()`에 TODO 주석이 있습니다.
   - `texture_path` 로딩/적용 로직을 복원하려면 여기에서 처리합니다.

3. `scenes/Race.tscn`
   - 현재 트랙 배경은 단색 `ColorRect`입니다.
   - 트랙 배경 이미지가 준비되면 `TrackArea` 하위에 `Sprite2D`를 추가합니다.

4. `scripts/RaceController.gd`
   - 현재 배경 텍스처 로딩 코드는 제거되었습니다.
   - 배경 이미지 동적 적용이 필요하면 `_ready()` 또는 별도 함수에서 처리합니다.
