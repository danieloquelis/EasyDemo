import Foundation

enum StringConstants {
    enum Path {
        static let moviesFolder = "Movies"
        static let appFolder = "EasyDemo"
        static let tempFolder = "tmp"
    }

    enum Permission {
        static let screenRecordingTitle = "Screen Recording Permission Required"
        static let screenRecordingMessage = "Please grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording."
        static let screenRecordingURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

        static let cameraTitle = "Camera Permission Required"
        static let cameraMessage = "Please grant camera permission in System Settings > Privacy & Security > Camera to use webcam overlay."
        static let cameraURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    }

    enum Recording {
        static let completedTitle = "Recording Complete"
        static let fileNamePrefix = "Recording_"
        static let fileExtension = "mov"
    }

    enum Window {
        static let selectionTitle = "Select Window to Record"
        static let excludedOwners = ["Window Server", "Dock", "SystemUIServer"]
        static let excludedTitles = ["", "Item-0"]
    }
}
