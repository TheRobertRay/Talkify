import Foundation

/// A deliberately narrow final-text pass for English Direct Dictation.
///
/// This is not a rewrite engine. It removes only speech debris whose intent
/// is clear, then repairs the punctuation and spacing left behind. Returning
/// the original text when the result would be empty keeps insertion fail-open.
enum DictationTextCleaner {
  private static let filler = #"(?<![\p{L}\p{N}'’])(?:[Uu]m+|[Uu]h+|[Ee]rm+)(?![\p{L}\p{N}'’])"#
  private static let softPunctuation = #"[,;:—–-]"#

  static func clean(_ text: String, locale: Locale) -> String {
    guard locale.language.languageCode?.identifier == "en" else { return text }

    var cleaned = text

    // Consume both commas around an interruption. Removing only the filler
    // would leave transcript punctuation such as "I, , think" behind.
    cleaned = cleaned.replacingPattern(
      #"\#(softPunctuation)+[ \t]*\#(filler)[ \t]*\#(softPunctuation)+"#,
      with: " "
    )
    cleaned = cleaned.replacingPattern(
      #"\#(filler)[ \t]*\#(softPunctuation)+[ \t]*"#,
      with: ""
    )
    cleaned = cleaned.replacingPattern(
      #"\#(softPunctuation)+[ \t]*\#(filler)"#,
      with: ""
    )
    cleaned = cleaned.replacingPattern(filler, with: "")

    // These repeats are overwhelmingly false starts, while words commonly
    // repeated for emphasis (no, very, really, so) are intentionally absent.
    cleaned = cleaned.replacingPattern(
      #"(?i)(?<![\p{L}\p{N}'’])(i(?:['’]m)?|my|we|the|a|an|it|this)(?![\p{L}\p{N}'’])(?:[ \t]*,[ \t]*|[ \t]+)\1(?![\p{L}\p{N}'’])"#,
      with: "$1"
    )

    cleaned = cleaned.replacingPattern(#"[ \t]{2,}"#, with: " ")
    cleaned = cleaned.replacingPattern(#"[ \t]+([,.;:!?])"#, with: "$1")
    cleaned = cleaned.replacingPattern(#"(?m)^[ \t]*[,;:—–-]+[ \t]*"#, with: "")
    cleaned = cleaned.replacingPattern(#"[ \t]+\n"#, with: "\n")
    cleaned = cleaned.replacingPattern(#"\n[ \t]+"#, with: "\n")
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned.isEmpty ? text : cleaned
  }
}

private extension String {
  func replacingPattern(_ pattern: String, with replacement: String) -> String {
    replacingOccurrences(
      of: pattern,
      with: replacement,
      options: .regularExpression
    )
  }
}
