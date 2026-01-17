# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Whisper Auto Captions is a macOS SwiftUI application that generates automatic captions/subtitles for Final Cut Pro X using OpenAI's Whisper model. It processes MP3 audio files and outputs FCPXML and SRT subtitle files.

## Build & Run

This is an Xcode project. Open `Whisper Auto Captions.xcodeproj` in Xcode to build and run.

```bash
# Open in Xcode
open "Whisper Auto Captions.xcodeproj"

# Build from command line
xcodebuild -project "Whisper Auto Captions.xcodeproj" -scheme "Whisper Auto Captions" build
```

## Architecture

**Single-file SwiftUI app** - All logic is in `Whisper Auto Captions/ContentView.swift`:

- `ContentView` - Root view that switches between HomeView and ProcessView
- `HomeView` - File selection, model/language configuration, triggers transcription
- `ProcessView` - Progress display, output preview, download/export options
- `DownloadDelegate` - Handles Whisper model download from HuggingFace

**Processing Pipeline** (in `whisper_auto_captions()` function):
1. MP3 → 16kHz WAV conversion using bundled `ffmpeg`
2. Split WAV into 10-minute segments for processing
3. Run `whisper.cpp` (`main` binary) on each segment to generate SRT files
4. Merge SRT segments with adjusted timestamps
5. Convert merged SRT to FCPXML format

**Bundled Binaries** (in app bundle):
- `ffmpeg` - Audio conversion
- `main` - whisper.cpp executable for transcription

**Whisper Models**: Downloaded on-demand from HuggingFace to `~/Library/Application Support/Whisper Auto Captions/ggml-{model}.bin`

## Key Functions in ContentView.swift

- `mp3_to_wav()` - Converts input to 16kHz WAV using ffmpeg
- `spilt_wav()` - Splits audio into 10-minute chunks
- `whisper_cpp()` - Runs whisper.cpp, parses progress from stderr
- `merge_srt()` - Combines SRT files with time offset adjustment
- `srt_to_fcpxml()` - Generates FCPXML for Final Cut Pro import
- `download_model()` - Downloads ggml models from HuggingFace

## Supported Languages

90+ languages via Whisper. Language codes mapped in `languagesMapping` dictionary.

## Output Formats

- **SRT** - Standard subtitle format
- **FCPXML** - Final Cut Pro X project with Basic Title elements
