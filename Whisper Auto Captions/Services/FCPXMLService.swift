import Foundation

// MARK: - FCPXML Service
/// Service for converting SRT files to FCPXML format for Final Cut Pro
struct FCPXMLService {
    
    // MARK: - Time Conversion
    static func srtTimeToFrame(srtTime: String, fps: Float) -> Int {
        // convert srt time to ms
        let ms = Int(srtTime.suffix(3))!
        let timeComponents = srtTime.prefix(srtTime.count - 4).split(separator: ":")
        let srtTimeMs = (Int(timeComponents[0])! * 3600 + Int(timeComponents[1])! * 60 + Int(timeComponents[2])!) * 1000 + ms
        // convert ms to frame
        let frame = Int(floor(Float(srtTimeMs) / (1000 / fps)))
        return frame
    }

    // MARK: - Text Formatting
    static func formatText(fullText: String) -> String {
        let words = fullText.split(separator: " ")
        var lines = [String]()
        for i in stride(from: 0, to: words.count, by: 16) {
            let endIndex = min(i + 16, words.count)
            let line = words[i..<endIndex].joined(separator: " ")
            lines.append(line)
        }
        let formattedText = lines.joined(separator: "\n")
        return formattedText
    }

    // MARK: - SRT to FCPXML Conversion
    static func srtToFCPXML(srtPath: String, fps: Float, projectName: String, language: String, width: Int = 1920, height: Int = 1080) -> String {
        do {
            let srtContent = try String(contentsOfFile: srtPath, encoding: .utf8)

            // Validate SRT content is not empty
            let trimmedContent = srtContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else {
                print("Error: SRT file is empty")
                return "Error: SRT file is empty"
            }

            let subtitles: [String] = trimmedContent.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            // Validate we have at least one subtitle
            guard !subtitles.isEmpty else {
                print("Error: No subtitles found in SRT file")
                return "Error: No subtitles found"
            }

            // Validate last subtitle format before accessing
            guard let lastSubtitle = subtitles.last else {
                print("Error: No subtitles found in SRT file")
                return "Error: No subtitles found"
            }

            let lastSubtitleLines = lastSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lastSubtitleLines.count >= 2 else {
                print("Error: Invalid subtitle format - insufficient lines")
                return "Error: Invalid subtitle format"
            }

            let timeRangeComponents = lastSubtitleLines[1].components(separatedBy: " --> ")
            guard timeRangeComponents.count >= 2 else {
                print("Error: Invalid subtitle format - missing time range")
                return "Error: Invalid subtitle format"
            }

            // extract total duration from srt
            let totalSrtTime = timeRangeComponents[1]
            let totalFrame = srtTimeToFrame(srtTime: totalSrtTime, fps: Float(fps))
            let hundredFoldTotalFrame = String(100 * totalFrame)
            let hundredFoldFps = String(Int(fps * 100))

            // fcpxml
            let fcpxmlElement = XMLElement(name: "fcpxml")
            fcpxmlElement.addAttribute(XMLNode.attribute(withName: "version", stringValue: "1.9") as! XMLNode)

            // resource
            let resourcesElement = XMLElement(name: "resources")

            // format - use dynamic resolution
            let formatName = VideoResolution.formatName(width: width, height: height, fps: fps)
            let formatElement = XMLElement(name: "format")
            formatElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: "r1") as! XMLNode)
            formatElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: formatName) as! XMLNode)
            formatElement.addAttribute(XMLNode.attribute(withName: "frameDuration", stringValue: "100/\(hundredFoldFps)s") as! XMLNode)
            formatElement.addAttribute(XMLNode.attribute(withName: "width", stringValue: String(width)) as! XMLNode)
            formatElement.addAttribute(XMLNode.attribute(withName: "height", stringValue: String(height)) as! XMLNode)
            formatElement.addAttribute(XMLNode.attribute(withName: "colorSpace", stringValue: "1-1-1 (Rec. 709)") as! XMLNode)
            resourcesElement.addChild(formatElement)

            // effect
            let effectElement = XMLElement(name: "effect")
            effectElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: "r2") as! XMLNode)
            effectElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Basic Title") as! XMLNode)
            effectElement.addAttribute(XMLNode.attribute(withName: "uid", stringValue: ".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti") as! XMLNode)
            resourcesElement.addChild(effectElement)

            // library
            let libraryElement = XMLElement(name: "library")

            // event
            let eventElement = XMLElement(name: "event")
            eventElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Whisper Auto Captions") as! XMLNode)
            libraryElement.addChild(eventElement)

            // project
            let projectElement = XMLElement(name: "project")
            projectElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "\(projectName)") as! XMLNode)
            eventElement.addChild(projectElement)

            // sequence
            let sequenceElement = XMLElement(name: "sequence")
            sequenceElement.addAttribute(XMLNode.attribute(withName: "format", stringValue: "r1") as! XMLNode)
            sequenceElement.addAttribute(XMLNode.attribute(withName: "tcStart", stringValue: "0s") as! XMLNode)
            sequenceElement.addAttribute(XMLNode.attribute(withName: "tcFormat", stringValue: "NDF") as! XMLNode)
            sequenceElement.addAttribute(XMLNode.attribute(withName: "audioLayout", stringValue: "stereo") as! XMLNode)
            sequenceElement.addAttribute(XMLNode.attribute(withName: "audioRate", stringValue: "48k") as! XMLNode)
            sequenceElement.addAttribute(XMLNode.attribute(withName: "duration", stringValue: "\(totalFrame)/\(hundredFoldFps)s") as! XMLNode)
            projectElement.addChild(sequenceElement)

            // spine
            let spineElement = XMLElement(name: "spine")
            sequenceElement.addChild(spineElement)

            // gap
            let gapElement = XMLElement(name: "gap")
            gapElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Gap") as! XMLNode)
            gapElement.addAttribute(XMLNode.attribute(withName: "offset", stringValue: "0s") as! XMLNode)
            gapElement.addAttribute(XMLNode.attribute(withName: "duration", stringValue: "\(hundredFoldTotalFrame)/\(hundredFoldFps)s") as! XMLNode)
            spineElement.addChild(gapElement)

            for (i, subtitle) in subtitles.enumerated() {
                let subtitleItem = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")

                // Skip malformed subtitles (need at least: index, time range, text)
                guard subtitleItem.count >= 3 else {
                    print("Warning: Skipping malformed subtitle at index \(i)")
                    continue
                }

                let timeRange = subtitleItem[1].components(separatedBy: " --> ")
                guard timeRange.count >= 2 else {
                    print("Warning: Skipping subtitle with invalid time range at index \(i)")
                    continue
                }

                let offset = timeRange[0]
                let end = timeRange[1]
                let offsetFrame = srtTimeToFrame(srtTime: offset, fps: fps)
                let endFrame = srtTimeToFrame(srtTime: end, fps: fps)
                let durationFrame = endFrame - offsetFrame

                let hundredFoldOffsetFrame = String(100 * offsetFrame)
                let hundredFoldDurationFrame = String(100 * durationFrame)
                var subtitleContent = subtitleItem[2]
                if language == "English" {
                    if subtitleContent.split(separator: " ").count > 16 {
                        subtitleContent = formatText(fullText: subtitleContent)
                    }
                }

                if language == "Chinese" {
                    // title
                    let titleElement = XMLElement(name: "title")
                    titleElement.addAttribute(XMLNode.attribute(withName: "ref", stringValue: "r2") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "lane", stringValue: "1") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "offset", stringValue: "\(hundredFoldOffsetFrame)/\(hundredFoldFps)s") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "duration", stringValue: "\(hundredFoldDurationFrame)/\(hundredFoldFps)s") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "\(subtitleContent) - Basic Title") as! XMLNode)

                    // param1
                    let param1Element = XMLElement(name: "param")
                    param1Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Position") as! XMLNode)
                    param1Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "9999/999166631/999166633/1/100/101") as! XMLNode)
                    param1Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "0 -465") as! XMLNode)
                    titleElement.addChild(param1Element)

                    // param2
                    let param2Element = XMLElement(name: "param")
                    param2Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Flatten") as! XMLNode)
                    param2Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "999/999166631/999166633/2/351") as! XMLNode)
                    param2Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "1") as! XMLNode)
                    titleElement.addChild(param2Element)

                    // param3
                    let param3Element = XMLElement(name: "param")
                    param3Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Alignment") as! XMLNode)
                    param3Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "9999/999166631/999166633/2/354/999169573/401") as! XMLNode)
                    param3Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "1 (Center)") as! XMLNode)
                    titleElement.addChild(param3Element)

                    // text
                    let textElement = XMLElement(name: "text")
                    titleElement.addChild(textElement)

                    // text style
                    let textStyleElement = XMLElement(name: "text-style")
                    textStyleElement.addAttribute(XMLNode.attribute(withName: "ref", stringValue: "ts\(String(i))") as! XMLNode)
                    textStyleElement.stringValue = subtitleContent
                    textElement.addChild(textStyleElement)

                    // text style def
                    let textStyleDefElement = XMLElement(name: "text-style-def")
                    textStyleDefElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: "ts\(String(i))") as! XMLNode)
                    titleElement.addChild(textStyleDefElement)

                    // text style 2
                    let textStyle2Element = XMLElement(name: "text-style")
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "font", stringValue: "PingFang SC") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontSize", stringValue: "50") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontFace", stringValue: "Semibold") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontColor", stringValue: "1 1 1 1") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "bold", stringValue: "1") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "shadowColor", stringValue: "0 0 0 0.75") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "shadowOffset", stringValue: "4 315") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "alignment", stringValue: "center") as! XMLNode)
                    textStyleDefElement.addChild(textStyle2Element)

                    gapElement.addChild(titleElement)

                } else {
                    // title
                    let titleElement = XMLElement(name: "title")
                    titleElement.addAttribute(XMLNode.attribute(withName: "ref", stringValue: "r2") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "lane", stringValue: "1") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "offset", stringValue: "\(hundredFoldOffsetFrame)/\(hundredFoldFps)s") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "duration", stringValue: "\(hundredFoldDurationFrame)/\(hundredFoldFps)s") as! XMLNode)
                    titleElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "\(subtitleContent) - Basic Title") as! XMLNode)

                    // param1
                    let param1Element = XMLElement(name: "param")
                    param1Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Position") as! XMLNode)
                    param1Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "9999/999166631/999166633/1/100/101") as! XMLNode)
                    param1Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "0 -465") as! XMLNode)
                    titleElement.addChild(param1Element)

                    // param2
                    let param2Element = XMLElement(name: "param")
                    param2Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Flatten") as! XMLNode)
                    param2Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "999/999166631/999166633/2/351") as! XMLNode)
                    param2Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "1") as! XMLNode)
                    titleElement.addChild(param2Element)

                    // param3
                    let param3Element = XMLElement(name: "param")
                    param3Element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "Alignment") as! XMLNode)
                    param3Element.addAttribute(XMLNode.attribute(withName: "key", stringValue: "9999/999166631/999166633/2/354/999169573/401") as! XMLNode)
                    param3Element.addAttribute(XMLNode.attribute(withName: "value", stringValue: "1 (Center)") as! XMLNode)
                    titleElement.addChild(param3Element)

                    // text
                    let textElement = XMLElement(name: "text")
                    titleElement.addChild(textElement)

                    // text style
                    let textStyleElement = XMLElement(name: "text-style")
                    textStyleElement.addAttribute(XMLNode.attribute(withName: "ref", stringValue: "ts\(String(i))") as! XMLNode)
                    textStyleElement.stringValue = subtitleContent
                    textElement.addChild(textStyleElement)

                    // text style def
                    let textStyleDefElement = XMLElement(name: "text-style-def")
                    textStyleDefElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: "ts\(String(i))") as! XMLNode)
                    titleElement.addChild(textStyleDefElement)

                    // text style 2
                    let textStyle2Element = XMLElement(name: "text-style")
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "font", stringValue: "Helvetica") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontSize", stringValue: "45") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontFace", stringValue: "Regular") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "fontColor", stringValue: "1 1 1 1") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "shadowColor", stringValue: "0 0 0 0.75") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "shadowOffset", stringValue: "4 315") as! XMLNode)
                    textStyle2Element.addAttribute(XMLNode.attribute(withName: "alignment", stringValue: "center") as! XMLNode)
                    textStyleDefElement.addChild(textStyle2Element)

                    gapElement.addChild(titleElement)
                }
            }

            // Add the resources and library elements to the fcpxml element
            fcpxmlElement.addChild(resourcesElement)
            fcpxmlElement.addChild(libraryElement)

            // Create the XML document with the fcpxml element as the root
            let xmlDoc = XMLDocument(rootElement: fcpxmlElement)

            // Set the XML document version and encoding
            xmlDoc.version = "1.0"
            xmlDoc.characterEncoding = "utf-8"

            // Write the XML document to the output file
            let xmlData = xmlDoc.xmlData(options: .nodePrettyPrint)
            let fileUrl = URL(fileURLWithPath: srtPath + ".fcpxml")
            try! xmlData.write(to: fileUrl)
            return srtPath + ".fcpxml"
        } catch {
            return "Error"
        }
    }
}

// MARK: - Legacy SRTConverter (for backward compatibility)
/// Alias for backward compatibility with existing code
typealias SRTConverter = FCPXMLService
