import AppKit

/// Read Aloud: speaks the focused application's selected text with Lewis,
/// Talkify's bundled local Kokoro voice. Errors surface through the HUD
/// message surface, matching Direct Dictation.
@MainActor
final class ReadAloudController {
  /// Follows inference and playback; the status menu mirrors both.
  var onSpeakingStateChange: ((Bool) -> Void)?

  private let hudController: DictationHUDController
  private let selectionReader = FocusedSelectionReader()
  private let player = LocalSpeechPlayer()

  init(hudController: DictationHUDController) {
    self.hudController = hudController
    player.onStateChange = { [weak self] active in
      self?.onSpeakingStateChange?(active)
    }
    player.onError = { [weak self] message in
      self?.hudController.showMessage(message)
    }
  }

  func toggle() {
    if player.isActive {
      stop()
    } else {
      speakSelection()
    }
  }

  func stop() {
    player.stop()
  }

  private func speakSelection() {
    guard PermissionService.hasAccessibilityAccess else {
      hudController.showMessage("Accessibility permission required")
      return
    }

    let selection = selectionReader.selectedText()?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let selection, !selection.isEmpty else {
      hudController.showMessage("No text selected")
      return
    }

    player.speak(selection)
  }
}
