import Foundation
import Testing
@testable import Talkify

struct DictationTextCleanerTests {
  private let english = Locale(identifier: "en_US")

  @Test func removesObviousFillersWithoutRewritingTheSentence() {
    #expect(
      DictationTextCleaner.clean(
        "Um, I think, uh, this is the right one.",
        locale: english
      ) == "I think this is the right one."
    )
    #expect(
      DictationTextCleaner.clean(
        "Send it um tomorrow.",
        locale: english
      ) == "Send it tomorrow."
    )
  }

  @Test func removesExtendedFillerSounds() {
    #expect(
      DictationTextCleaner.clean(
        "Ummm, this is, uhhh, still my sentence.",
        locale: english
      ) == "this is still my sentence."
    )
  }

  @Test func collapsesOnlyHighConfidenceRepeatedStarts() {
    #expect(
      DictationTextCleaner.clean(
        "My, my text is accurate, but I I want it cleaner.",
        locale: english
      ) == "My text is accurate, but I want it cleaner."
    )
    #expect(
      DictationTextCleaner.clean(
        "No no no, that was very very good.",
        locale: english
      ) == "No no no, that was very very good."
    )
  }

  @Test func preservesMeaningfulHesitationAndWordsContainingFillerText() {
    let text = "Well, I was like, you know, unsure about the album. Hmm."
    #expect(DictationTextCleaner.clean(text, locale: english) == text)
    #expect(DictationTextCleaner.clean("The UM system is online.", locale: english) == "The UM system is online.")
  }

  @Test func preservesOtherLanguagesExactly() {
    let german = "Um die Ecke ist ein Café."
    #expect(
      DictationTextCleaner.clean(german, locale: Locale(identifier: "de_DE")) == german
    )
  }

  @Test func preservesTheOriginalWhenItContainsOnlyAFiller() {
    #expect(DictationTextCleaner.clean("Um", locale: english) == "Um")
  }

  @Test func keepsParagraphBoundariesWhileRepairingSpacing() {
    let text = "Um, first thought.  \n  Uh, second thought."
    #expect(
      DictationTextCleaner.clean(text, locale: english)
        == "first thought.\nsecond thought."
    )
  }
}
