<p align="center">
    <img height="256" src="https://github.com/shaishaicookie/fcpx-auto-captions/blob/main/Whisper%20Auto%20Captions/Assets.xcassets/AppIcon.appiconset/1024.png" />
</p>
<h1 align="center">Whisper Auto Captions</h1>
<p align="center">OpenAI Whisper 모델을 활용한 Final Cut Pro 자동 자막 생성</p>

<p align="center">
    <a href="README.md">English</a>
</p>

## 데모
<img src="demo.gif">

## 데모 영상
Youtube: [https://youtu.be/2_QOACyuZIk](https://youtu.be/n1qMG87aJcw)

## 웹사이트
https://whisperautocaptions.com/

## 다운로드
* [Apple Chip (M1/M2/M3)](https://drive.google.com/file/d/1RGnyiPTWGtHn8hSHElsB72gZtx9nSAXQ/view?usp=sharing)
* [Intel Chip](https://drive.google.com/file/d/1AgU3_XNimv1Z_pE5VeFYyhG9O_eFaina/view?usp=sharing)
* [중국 다운로드](https://vu3mopq3x8.feishu.cn/docx/Go9IdrSkpochcoxpgHfcl7nhn2d)

## 주요 기능
* 90개 이상의 언어에서 정확한 음성 인식
* 실시간 출력 및 진행률 표시
* FCPXML을 Final Cut Pro X로 직접 전송
* SRT 파일 다운로드 - Adobe Premiere Pro, DaVinci Resolve, Sony Vegas에서 편집 가능
* **SRT → FCPXML 변환** - 기존 SRT 파일을 FCPXML 형식으로 변환
* **고급 whisper.cpp 설정** - 프리셋 지원 (가장 빠름, 빠름, 균형, 품질, 최고 품질)
* **다국어 UI** - 영어, 한국어, 일본어 지원

## 고급 설정

whisper.cpp의 다양한 설정 옵션을 제공합니다:

### 프리셋
| 프리셋 | 용도 |
|--------|------|
| 가장 빠름 | 빠른 미리보기, 최대 속도 |
| 빠름 | 합리적인 정확도로 빠른 처리 |
| 균형 | 대부분의 경우에 권장 |
| 품질 | 속도를 희생하여 높은 정확도 |
| 최고 품질 | 최대 정확도, 상당히 느림 |
| 사용자 정의 | 모든 매개변수 수동 조정 |

### 설정 카테고리
- **품질**: 빔 크기, best-of 샘플링, 엔트로피 임계값
- **성능**: 스레드 수, 프로세서 수, 플래시 어텐션
- **출력**: 출력 형식 옵션
- **고급**: 온도, 오디오 컨텍스트 설정
