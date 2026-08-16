import Foundation
@preconcurrency import SherpaOnnx

struct LocalSpeechAudio: Sendable {
  let samples: [Float]
  let sampleRate: Double
}

enum LocalSpeechError: LocalizedError {
  case modelMissing
  case engineFailed
  case generationFailed

  var errorDescription: String? {
    switch self {
    case .modelMissing:
      "Lewis voice model is missing"
    case .engineFailed:
      "Lewis voice could not start"
    case .generationFailed:
      "Lewis could not read that text"
    }
  }
}

final class SpeechGenerationCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  func cancel() {
    lock.withLock { cancelled = true }
  }

  var isCancelled: Bool {
    lock.withLock { cancelled }
  }
}

/// The one local Read Aloud inference engine. It owns Kokoro for the life of
/// the app so repeated selections avoid model reload latency. Nothing is
/// written to disk: generated samples move directly into AVAudioEngine.
actor KokoroSpeechEngine {
  static let shared = KokoroSpeechEngine()

  private static let lewisSpeakerID = 10
  private var engine: SherpaOnnxOfflineTtsWrapper?

  func generate(
    text: String,
    cancellation: SpeechGenerationCancellation
  ) throws -> LocalSpeechAudio {
    if cancellation.isCancelled { throw CancellationError() }

    let engine = try loadEngine()
    var generation = SherpaOnnxGenerationConfigSwift()
    generation.sid = Self.lewisSpeakerID
    generation.speed = 1
    generation.silenceScale = 0.2

    let cancellationPointer = Unmanaged.passUnretained(cancellation).toOpaque()
    let callback: TtsProgressCallbackWithArg = { _, _, _, pointer in
      guard let pointer else { return 0 }
      let token = Unmanaged<SpeechGenerationCancellation>
        .fromOpaque(pointer)
        .takeUnretainedValue()
      return token.isCancelled ? 0 : 1
    }

    let generated = engine.generateWithConfig(
      text: text,
      config: generation,
      callback: callback,
      arg: cancellationPointer
    )

    if cancellation.isCancelled { throw CancellationError() }
    let samples = generated.samples
    guard !samples.isEmpty, generated.sampleRate > 0 else {
      throw LocalSpeechError.generationFailed
    }

    return LocalSpeechAudio(
      samples: samples,
      sampleRate: Double(generated.sampleRate)
    )
  }

  private func loadEngine() throws -> SherpaOnnxOfflineTtsWrapper {
    if let engine { return engine }

    let modelDirectory = try modelDirectory()
    let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
      model: modelDirectory.appendingPathComponent("model.onnx").path,
      voices: modelDirectory.appendingPathComponent("voices.bin").path,
      tokens: modelDirectory.appendingPathComponent("tokens.txt").path,
      dataDir: modelDirectory.appendingPathComponent("espeak-ng-data").path
    )
    let model = sherpaOnnxOfflineTtsModelConfig(
      kokoro: kokoro,
      numThreads: 2,
      debug: 0,
      provider: "cpu"
    )
    var configuration = sherpaOnnxOfflineTtsConfig(model: model)
    let candidate = SherpaOnnxOfflineTtsWrapper(config: &configuration)
    guard candidate.tts != nil else { throw LocalSpeechError.engineFailed }

    engine = candidate
    return candidate
  }

  private func modelDirectory() throws -> URL {
    guard let resources = Bundle.main.resourceURL else {
      throw LocalSpeechError.modelMissing
    }
    let directory = resources
      .appendingPathComponent("Models", isDirectory: true)
      .appendingPathComponent("kokoro-en-v0_19", isDirectory: true)
    let required = ["model.onnx", "voices.bin", "tokens.txt", "espeak-ng-data"]
    guard required.allSatisfy({
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent($0).path
      )
    }) else {
      throw LocalSpeechError.modelMissing
    }
    return directory
  }
}
