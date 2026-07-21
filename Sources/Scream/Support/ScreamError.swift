import Foundation

enum ScreamError: LocalizedError {
    case audioEngineUnavailable
    case modelNotLoaded
    case recordingTooShort
    case secureInputActive
    case insertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioEngineUnavailable:
            "The microphone could not be started."
        case .modelNotLoaded:
            "No transcription model is loaded yet."
        case .recordingTooShort:
            "The recording was too short to transcribe."
        case .secureInputActive:
            "A secure text field is focused — dictation is unavailable."
        case .insertionFailed(let reason):
            "Could not insert text: \(reason)"
        }
    }
}
