import AVFoundation
import Flutter

/// PCM mono 16 bits via AVFoundation. Le fichier temporaire porte
/// `podavio-pcm-` pour que Dart puisse l’effacer sans toucher l’épisode.
enum AudioDecodePlugin {
  static let channelName = "fr.podavio.podavio/audio_decode"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "decodeToPcm" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let path = (args?["path"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let rate = args?["sampleRate"] as? Int ?? 11025
      guard !path.isEmpty else {
        result(nil)
        return
      }
      Task {
        do {
          let decoded = try await decode(path: path, sampleRate: rate)
          DispatchQueue.main.async { result(decoded) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "decode",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private static func decode(path: String, sampleRate: Int) async throws -> [String: Any]? {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let tracks: [AVAssetTrack]
    if #available(iOS 16.0, *) {
      tracks = try await asset.loadTracks(withMediaType: .audio)
    } else {
      tracks = asset.tracks(withMediaType: .audio)
    }
    guard let track = tracks.first else { return nil }
    let reader = try AVAssetReader(asset: asset)
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { return nil }
    reader.add(output)
    guard reader.startReading() else {
      throw reader.error ?? decodeError("Lecture audio impossible.")
    }
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("podavio-pcm-\(UUID().uuidString).pcm")
    FileManager.default.createFile(atPath: file.path, contents: nil)
    let handle = try FileHandle(forWritingTo: file)
    var samples = 0
    while let buffer = output.copyNextSampleBuffer() {
      defer { CMSampleBufferInvalidate(buffer) }
      guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
      let length = CMBlockBufferGetDataLength(block)
      var data = Data(count: length)
      data.withUnsafeMutableBytes { raw in
        if let base = raw.baseAddress {
          _ = CMBlockBufferCopyDataBytes(
            block,
            atOffset: 0,
            dataLength: length,
            destination: base
          )
        }
      }
      handle.write(data)
      samples += length / 2
    }
    try handle.close()
    if reader.status == .failed {
      try? FileManager.default.removeItem(at: file)
      throw reader.error ?? decodeError("Décodage audio interrompu.")
    }
    if samples <= 0 {
      try? FileManager.default.removeItem(at: file)
      return nil
    }
    return [
      "path": file.path,
      "sampleRate": sampleRate,
      "samples": samples,
      "durationMs": samples * 1000 / sampleRate,
    ]
  }

  private static func decodeError(_ message: String) -> NSError {
    NSError(domain: "fr.podavio.podavio", code: 1, userInfo: [
      NSLocalizedDescriptionKey: message,
    ])
  }
}
