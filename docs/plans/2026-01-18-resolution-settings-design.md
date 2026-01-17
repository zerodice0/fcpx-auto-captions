# FCPXML Resolution Settings Feature Design

## Overview

SRT Converter 탭에 해상도 설정 기능을 추가하여 사용자가 FCPXML 출력의 해상도를 선택할 수 있도록 한다.

## Requirements

- 프리셋 해상도 옵션 제공 (720p, 1080p, 4K UHD, 4K DCI, Vertical 1080p)
- 커스텀 해상도 입력 지원
- Final Cut Pro 호환성 기준 유효성 검사 (640~8192, 짝수 권장)

## Design

### 1. Data Model

**VideoResolution enum 추가 위치:** `ContentView.swift` 또는 별도 Models 파일

```swift
enum VideoResolution: String, CaseIterable, Identifiable {
    case hd720p = "720p HD"
    case fullHD1080p = "1080p Full HD"
    case uhd4K = "4K UHD"
    case dci4K = "4K DCI"
    case vertical1080p = "1080p Vertical"
    case custom = "Custom"

    var id: String { rawValue }

    var width: Int {
        switch self {
        case .hd720p: return 1280
        case .fullHD1080p: return 1920
        case .uhd4K: return 3840
        case .dci4K: return 4096
        case .vertical1080p: return 1080
        case .custom: return 1920
        }
    }

    var height: Int {
        switch self {
        case .hd720p: return 720
        case .fullHD1080p: return 1080
        case .uhd4K: return 2160
        case .dci4K: return 2160
        case .vertical1080p: return 1920
        case .custom: return 1080
        }
    }
}
```

**유효성 검사:**
- 범위: 640 ~ 8192
- 짝수 값 권장 (경고만, 차단하지 않음)

### 2. UI Changes

**SRTConverterInputView 수정:**

기존 필드 사이에 Resolution Picker 추가:
- Frame Rate 아래, Language 위에 배치
- Custom 선택 시 Width/Height 입력 필드 표시

```
SRT File:      [Choose File]
Project Name:  [____________]
Frame Rate:    [____________]
Resolution:    [1080p Full HD ▼]
Language:      [English ▼]
```

Custom 선택 시:
```
Resolution:    [Custom ▼]
               Width: [____] × Height: [____]
```

**State 변수:**
- `@State private var selectedResolution: VideoResolution = .fullHD1080p`
- `@State private var customWidth: String = "1920"`
- `@State private var customHeight: String = "1080"`

### 3. FCPXML Generation Logic

**srt_to_fcpxml 함수 시그니처 변경:**

```swift
func srtToFCPXML(srtPath: String, fps: Float, projectName: String,
                  language: String, width: Int, height: Int) -> String
```

**포맷 이름 생성 로직:**

```swift
func generateFormatName(width: Int, height: Int, fps: Float) -> String {
    let fpsInt = Int(fps * 100)

    switch (width, height) {
    case (1280, 720):  return "FFVideoFormat720p\(fpsInt)"
    case (1920, 1080): return "FFVideoFormat1080p\(fpsInt)"
    case (3840, 2160): return "FFVideoFormat3840x2160p\(fpsInt)"
    case (4096, 2160): return "FFVideoFormat4096x2160p\(fpsInt)"
    case (1080, 1920): return "FFVideoFormat1080x1920p\(fpsInt)"
    default:          return "FFVideoFormatRateUndefined"
    }
}
```

### 4. Affected Files

1. **ContentView.swift**
   - `VideoResolution` enum 추가
   - `SRTConverterInputView` UI 수정
   - `SRTConverterView` state 추가
   - `srt_to_fcpxml()` 함수 수정

2. **SRTService.swift** (선택적)
   - 인터페이스 업데이트

## Implementation Steps

1. VideoResolution enum 추가
2. SRTConverterInputView에 Resolution Picker UI 추가
3. Custom 해상도 입력 필드 및 유효성 검사 추가
4. srt_to_fcpxml 함수에 width/height 파라미터 추가
5. FCPXML 생성 로직에서 동적 해상도 적용
6. 테스트

## References

- [FCPXML Reference - Apple Developer](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)
- [FCP Cafe - FCPXML](https://fcp.cafe/developers/fcpxml/)
