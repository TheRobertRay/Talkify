import AVFAudio
import Foundation

/// Turns ephemeral Kokoro samples into playback. A second Read Aloud press
/// cancels inference or stops audio immediately; no temporary WAV is created.
@MainActor
final class LocalSpeechPlayer {
  var onStateChange: ((Bool) -> Void)?
  var onError: ((String) -> Void)?

  private let audioEngine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  private var generationTask: Task<Void, Never>?
  private var cancellation: SpeechGenerationCancellation?
  private var playbackID = UUID()

  private(set) var isActive = false

  init() {
    audioEngine.attach(playerNode)
  }

  func speak(_ text: String) {
    stop(notify: false)

    let cancellation = SpeechGenerationCancellation()
    let playbackID = UUID()
    self.cancellation = cancellation
    self.playbackID = playbackID
    setActive(true)

    generationTask = Task { [weak self] in
      do {
        let audio = try await KokoroSpeechEngine.shared.generate(
          text: text,
          cancellation: cancellation
        )
        guard let self, self.playbackID == playbackID, !cancellation.isCancelled else {
          return
        }
        try self.play(audio, playbackID: playbackID)
      } catch is CancellationError {
        // A second shortcut press is an ordinary stop, not an error.
      } catch {
        guard let self, self.playbackID == playbackID else { return }
        self.stop()
        self.onError?(error.localizedDescription)
      }
    }
  }

  func stop() {
    stop(notify: true)
  }

  private func stop(notify: Bool) {
    playbackID = UUID()
    cancellation?.cancel()
    cancellation = nil
    generationTask?.cancel()
    generationTask = nil
    playerNode.stop()
    audioEngine.stop()
    if notify { setActive(false) }
  }

  private func play(_ audio: LocalSpeechAudio, playbackID: UUID) throws {
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: audio.sampleRate,
      channels: 1,
      interleaved: false
    ),
    let buffer = AVAudioPCMBuffer(
      pcmFormat: format,
      frameCapacity: AVAudioFrameCount(audio.samples.count)
    ),
    let channel = buffer.floatChannelData?[0] else {
      throw LocalSpeechError.generationFailed
    }

    buffer.frameLength = AVAudioFrameCount(audio.samples.count)
    audio.samples.withUnsafeBufferPointer { source in
      channel.update(from: source.baseAddress!, count: source.count)
    }

    audioEngine.stop()
    audioEngine.disconnectNodeOutput(playerNode)
    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
    try audioEngine.start()
    playerNode.scheduleBuffer(
      buffer,
      completionCallbackType: .dataPlayedBack
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.playbackID == playbackID else { return }
        self.generationTask = nil
        self.cancellation = nil
        self.audioEngine.stop()
        self.setActive(false)
      }
    }
    playerNode.play()
  }

  private func setActive(_ active: Bool) {
    guard isActive != active else { return }
    isActive = active
    onStateChange?(active)
  }
}
