import Foundation

/// Interprets spoken commands in a finished transcript. Pure `String → String`
/// so it is trivially unit-testable.
enum VoiceCommandProcessor {
    static func apply(to text: String) -> String {
        var result = text

        // "scratch that" discards everything dictated before (and including) it.
        if let range = result.ranges(of: /(?i)\bscratch that\b[.,!?]?\s*/).last {
            result = String(result[range.upperBound...])
        }

        // Paragraph and line breaks. A leading comma is a Whisper artifact and
        // is swallowed; a leading period is real sentence punctuation and stays.
        result = result.replacing(/,?\s*\bnew paragraph\b[.,]?\s*/.ignoresCase(), with: "\n\n")
        result = result.replacing(/,?\s*\bnew line\b[.,]?\s*/.ignoresCase(), with: "\n")

        // "all caps … end caps" uppercases the span.
        while let match = result.firstMatch(
            of: /\ball caps\b[.,]?\s*(.+?)\s*\bend caps\b[.,!?]?/.ignoresCase()
        ) {
            result.replaceSubrange(match.range, with: match.output.1.uppercased())
        }

        // Capitalize the first letter after any break we inserted.
        result = capitalizeAfterNewlines(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func capitalizeAfterNewlines(_ text: String) -> String {
        var characters = Array(text)
        var atLineStart = false
        for index in characters.indices {
            let character = characters[index]
            if character.isNewline {
                atLineStart = true
            } else if atLineStart, character.isLetter {
                characters[index] = Character(character.uppercased())
                atLineStart = false
            } else if !character.isWhitespace {
                atLineStart = false
            }
        }
        return String(characters)
    }
}
