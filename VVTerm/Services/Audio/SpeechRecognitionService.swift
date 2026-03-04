import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var transcribedText = ""
    @Published var partialTranscription = ""

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var stopContinuation: CheckedContinuation<String, Never>?
    private var stopTimeoutTask: Task<Void, Never>?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Recognition Control

    func startRecognition() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognitionUnavailable
        }

        resolveStopContinuationIfNeeded(with: bestAvailableTranscription())
        stopTimeoutTask?.cancel()
        stopTimeoutTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result {
                    let transcription = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.transcribedText = transcription
                        self.completeRecognition(with: transcription)
                        return
                    }
                    self.partialTranscription = transcription
                }

                if error != nil {
                    self.completeRecognition(with: self.bestAvailableTranscription())
                }
            }
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stopRecognition(timeout: Duration = .seconds(2)) async -> String {
        guard recognitionRequest != nil || recognitionTask != nil else {
            return bestAvailableTranscription()
        }

        return await withCheckedContinuation { continuation in
            if stopContinuation != nil {
                continuation.resume(returning: bestAvailableTranscription())
                return
            }

            stopContinuation = continuation
            recognitionRequest?.endAudio()

            stopTimeoutTask?.cancel()
            stopTimeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: timeout)
                await MainActor.run {
                    guard self.stopContinuation != nil else { return }
                    self.recognitionTask?.cancel()
                    self.completeRecognition(with: self.bestAvailableTranscription())
                }
            }
        }
    }

    func transcribe(samples: [Float], sampleRate: Double) async throws -> String {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognitionUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vvterm-transcription-\(UUID().uuidString)")
            .appendingPathExtension("caf")

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)

        if let channel = buffer.floatChannelData?.pointee {
            samples.withUnsafeBufferPointer { ptr in
                channel.update(from: ptr.baseAddress!, count: samples.count)
            }
        }

        try file.write(from: buffer)

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let cleanup: () -> Void = {
                try? FileManager.default.removeItem(at: tempURL)
            }

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                if finished { return }

                if let error {
                    finished = true
                    cleanup()
                    Task { @MainActor in
                        self?.recognitionTask = nil
                    }
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else { return }
                if result.isFinal {
                    finished = true
                    cleanup()
                    Task { @MainActor in
                        self?.recognitionTask = nil
                    }
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    func cancelRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        completeRecognition(with: bestAvailableTranscription())

        transcribedText = ""
        partialTranscription = ""
    }

    func resetTranscriptions() {
        transcribedText = ""
        partialTranscription = ""
    }

    private func completeRecognition(with text: String) {
        stopTimeoutTask?.cancel()
        stopTimeoutTask = nil
        resolveStopContinuationIfNeeded(with: text)
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func resolveStopContinuationIfNeeded(with text: String) {
        guard let continuation = stopContinuation else { return }
        stopContinuation = nil
        continuation.resume(returning: text)
    }

    private func bestAvailableTranscription() -> String {
        let primary = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty {
            return primary
        }

        return partialTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Errors

    enum SpeechRecognitionError: LocalizedError {
        case recognitionUnavailable

        var errorDescription: String? {
            switch self {
            case .recognitionUnavailable:
                return "Speech recognition is not available. Please enable Siri in System Settings > Siri & Spotlight."
            }
        }
    }
}
