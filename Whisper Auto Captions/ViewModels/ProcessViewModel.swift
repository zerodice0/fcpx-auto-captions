import Foundation
import AppKit

// MARK: - Process ViewModel
class ProcessViewModel: ObservableObject {
    
    // MARK: - Open in Final Cut Pro
    static func openInFinalCutPro(fcpxmlPath: String) {
        let command =
        """
        tell application "Final Cut Pro"
            launch
            activate
            open POSIX file "\(fcpxmlPath)"
        end tell
        """
        DispatchQueue.global(qos: .background).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: command) {
                _ = scriptObject.executeAndReturnError(&error)
            }
        }
    }
}
