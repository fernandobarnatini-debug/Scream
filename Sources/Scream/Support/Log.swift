import os

enum Log {
    private static let subsystem = "com.fernando.scream"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let insertion = Logger(subsystem: subsystem, category: "insertion")
    static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
}
