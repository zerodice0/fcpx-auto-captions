//
//  SRTService.swift
//  Whisper Auto Captions
//
//  Handles SRT file operations and FCPXML conversion
//

import Foundation

/// Service for SRT file operations
class SRTService {
    // MARK: - Singleton
    static let shared = SRTService()
    private init() {}

    // MARK: - Merge SRT Files
    /// Merge multiple SRT files into one, adjusting timestamps
    func mergeSRT(srtFiles: [String]) -> String {
        guard !srtFiles.isEmpty else { return "" }

        let mergedSrtPath = srtFiles[0] + "_merged.srt"
        var mergedContents = ""
        var index = 1

        for (i, srtPath) in srtFiles.enumerated() {
            do {
                let srtContent = try String(contentsOfFile: srtPath, encoding: .utf8)
                let subtitles: [String] = srtContent
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n\n")

                for subtitle in subtitles {
                    let subtitleItem = subtitle
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: "\n")

                    guard subtitleItem.count >= 3 else { continue }

                    let timeRange = subtitleItem[1].components(separatedBy: " --> ")
                    guard timeRange.count >= 2 else { continue }

                    let start = timeRange[0]
                    let end = timeRange[1]

                    let newStart = adjustSrtTime(srtTime: start, factor: i)
                    let newEnd = adjustSrtTime(srtTime: end, factor: i)

                    let newTimeRange = newStart + " --> " + newEnd
                    let subtitleContent = subtitleItem[2]

                    mergedContents += "\(index)\n"
                    mergedContents += "\(newTimeRange)\n"
                    mergedContents += "\(subtitleContent)\n\n"
                    index += 1
                }
            } catch {
                continue
            }
        }

        do {
            try mergedContents.write(toFile: mergedSrtPath, atomically: true, encoding: .utf8)
        } catch {
            // Handle error silently
        }

        return mergedSrtPath
    }

    // MARK: - Adjust SRT Time
    /// Adjust SRT timestamp by adding 10 minutes * factor
    func adjustSrtTime(srtTime: String, factor: Int) -> String {
        let timeComponents = srtTime.components(separatedBy: ":")
        guard timeComponents.count >= 3 else { return srtTime }

        let hours = Int(timeComponents[0]) ?? 0
        let minutes = Int(timeComponents[1]) ?? 0
        let secondsAndMilliseconds = timeComponents[2].components(separatedBy: ",")
        let seconds = Int(secondsAndMilliseconds[0]) ?? 0

        let totalMinutes = (hours * 60) + minutes
        let newTotalMinutes = totalMinutes + (factor * 10)
        let newHours = newTotalMinutes / 60
        let newMinutes = newTotalMinutes % 60

        let milliseconds = secondsAndMilliseconds.count > 1 ? secondsAndMilliseconds[1] : "000"
        let newTime = String(format: "%02d:%02d:%02d,%@", newHours, newMinutes, seconds, milliseconds)

        return newTime
    }

    // MARK: - SRT to FCPXML
    /// Convert SRT file to FCPXML format for Final Cut Pro
    func srtToFCPXML(srtPath: String, fps: Float, projectName: String, language: String) -> String {
        return SRTConverter.srtToFCPXML(
            srtPath: srtPath,
            fps: fps,
            projectName: projectName,
            language: language
        )
    }

    // MARK: - Time Conversion Helpers
    /// Convert SRT time string to frame number
    func srtTimeToFrame(srtTime: String, fps: Float) -> Int {
        return SRTConverter.srtTimeToFrame(srtTime: srtTime, fps: fps)
    }

    /// Format text by breaking into lines of 16 words
    func formatText(fullText: String) -> String {
        return SRTConverter.formatText(fullText: fullText)
    }
}
