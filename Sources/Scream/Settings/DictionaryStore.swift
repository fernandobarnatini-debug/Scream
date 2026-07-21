import Foundation
import Observation

struct DictionaryRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var find: String
    var replace: String
    var caseSensitive = false
}

/// User-managed vocabulary: bias words steer Whisper via its prompt; rules are
/// literal word-boundary find/replace applied to every transcript, in order.
@MainActor
@Observable
final class DictionaryStore {
    var biasWords: [String] {
        didSet { save() }
    }
    var rules: [DictionaryRule] {
        didSet { save() }
    }

    private struct FileFormat: Codable {
        var biasWords: [String]
        var rules: [DictionaryRule]
    }

    nonisolated static let defaultFileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Scream/dictionary.json")

    private let fileURL: URL

    init(fileURL: URL = DictionaryStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(FileFormat.self, from: data) {
            biasWords = decoded.biasWords
            rules = decoded.rules
        } else {
            biasWords = []
            rules = []
        }
    }

    /// Fed into Whisper's decoding prompt to bias recognition toward these terms.
    var biasPrompt: String? {
        let words = biasWords.filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        return words.joined(separator: ", ") + "."
    }

    func apply(to text: String) -> String {
        var result = text
        for rule in rules where !rule.find.isEmpty {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: rule.find))\\b"
            let options: NSRegularExpression.Options = rule.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: rule.replace)
            )
        }
        return result
    }

    private func save() {
        let payload = FileFormat(biasWords: biasWords, rules: rules)
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
