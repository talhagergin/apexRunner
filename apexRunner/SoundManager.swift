//
//  SoundManager.swift
//  apexRunner
//
//  Synthesizes all game sounds procedurally — no audio asset files required.
//  Uses AVAudioEngine + PCM buffer generation (sine sweeps, arpeggios, noise).
//

import AVFoundation

// MARK: - SoundManager

final class SoundManager {

    static let shared = SoundManager()

    // MARK: Sound Events
    enum SoundEvent {
        case laneSwitch
        case coinCollect
        case crash
        case milestone
        case comboUp
        case ambient
    }

    // MARK: Private
    private let engine = AVAudioEngine()
    private let fxNode = AVAudioPlayerNode()
    private let ambientNode = AVAudioPlayerNode()
    private var buffers: [SoundEvent: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44100
    private var isEngineReady = false

    private init() {
        setupAudioSession()
        setupEngine()
        // Build buffers on background thread — heavy work
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.buildBuffers()
        }
    }

    // MARK: - Public API

    func play(_ event: SoundEvent) {
        guard isEngineReady else { return }

        switch event {
        case .ambient:
            guard let buf = buffers[.ambient] else { return }
            ambientNode.stop()
            ambientNode.scheduleBuffer(buf, at: nil, options: .loops)
            if !ambientNode.isPlaying { ambientNode.play() }

        default:
            guard let buf = buffers[event] else { return }
            fxNode.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            if !fxNode.isPlaying { fxNode.play() }
        }
    }

    func startAmbient() { play(.ambient) }

    func stopAmbient() { ambientNode.stop() }

    func setFXVolume(_ v: Float) { fxNode.volume = v }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
        } catch { }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType),
            type == .ended
        else { return }
        try? engine.start()
        startAmbient()
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(fxNode)
        engine.attach(ambientNode)
        engine.connect(fxNode, to: engine.mainMixerNode, format: format)
        engine.connect(ambientNode, to: engine.mainMixerNode, format: format)
        fxNode.volume = 0.65
        ambientNode.volume = 0.14
        engine.mainMixerNode.outputVolume = 1.0
        do {
            try engine.start()
            isEngineReady = true
        } catch { }
    }

    // MARK: - Buffer Construction

    private func buildBuffers() {
        buffers[.laneSwitch] = makeSweep(fromHz: 520, toHz: 220, duration: 0.09, volume: 0.45)
        buffers[.coinCollect] = makeArpeggio(freqs: [523, 659, 784], noteDuration: 0.07, volume: 0.55)
        buffers[.crash]       = makeCrash(volume: 0.80)
        buffers[.milestone]   = makeArpeggio(freqs: [523, 659, 784, 1047], noteDuration: 0.09, volume: 0.65)
        buffers[.comboUp]     = makeSweep(fromHz: 380, toHz: 920, duration: 0.11, volume: 0.38)
        buffers[.ambient]     = makeAmbientPad(duration: 4.0, volume: 1.0)
    }

    // MARK: - Synthesis Primitives

    /// Sine-wave frequency sweep (e.g. whoosh, laser).
    private func makeSweep(fromHz: Float, toHz: Float, duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buf.frameLength = totalFrames

        let data = buf.floatChannelData![0]
        var phase: Float = 0

        for i in 0..<Int(totalFrames) {
            let progress = Float(i) / Float(totalFrames)
            let freq = fromHz + (toHz - fromHz) * progress
            let phaseInc = 2.0 * Float.pi * freq / Float(sampleRate)

            // Attack-release envelope
            let attack = min(progress * 12.0, 1.0)
            let release = max(1.0 - progress * 1.3, 0.0)
            data[i] = sin(phase) * attack * release * volume

            phase += phaseInc
            if phase > 2.0 * Float.pi { phase -= 2.0 * Float.pi }
        }
        return buf
    }

    /// Short arpeggio (e.g. coin collect, level-up chime).
    private func makeArpeggio(freqs: [Float], noteDuration: Double, volume: Float) -> AVAudioPCMBuffer {
        let framesPerNote = Int(sampleRate * noteDuration)
        let totalFrames = AVAudioFrameCount(framesPerNote * freqs.count)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buf.frameLength = totalFrames

        let data = buf.floatChannelData![0]
        var phase: Float = 0

        for (noteIdx, freq) in freqs.enumerated() {
            let phaseInc = 2.0 * Float.pi * freq / Float(sampleRate)
            for localFrame in 0..<framesPerNote {
                let globalFrame = noteIdx * framesPerNote + localFrame
                guard globalFrame < Int(totalFrames) else { break }
                let progress = Float(localFrame) / Float(framesPerNote)
                // Punchy envelope: instant attack, exponential tail
                let env = exp(-progress * 4.0)
                data[globalFrame] = sin(phase) * env * volume
                phase += phaseInc
            }
        }
        return buf
    }

    /// Layered crash: low thump + white-noise snap.
    private func makeCrash(volume: Float) -> AVAudioPCMBuffer {
        let duration: Double = 0.45
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buf.frameLength = totalFrames

        let data = buf.floatChannelData![0]
        var thumpPhase: Float = 0

        for i in 0..<Int(totalFrames) {
            let progress = Float(i) / Float(totalFrames)

            // Descending thump (80→40 Hz)
            let thumpFreq: Float = 80.0 * (1.0 - progress * 0.5)
            thumpPhase += 2.0 * Float.pi * thumpFreq / Float(sampleRate)
            let thump = sin(thumpPhase) * exp(-progress * 8.0)

            // Noise snap — heavy at start, fades fast
            let noise = Float.random(in: -1...1) * exp(-progress * 18.0) * 0.45

            let env = exp(-progress * 4.5)
            data[i] = (thump + noise) * env * volume
        }
        return buf
    }

    /// Looping synthwave pad — layered sine harmonics with slow tremolo.
    private func makeAmbientPad(duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buf.frameLength = totalFrames

        let data = buf.floatChannelData![0]

        // A-minor pad chord: A1-E2-A2-E3-A3 (55, 82.5, 110, 165, 220 Hz)
        let harmonics: [(Float, Float)] = [
            (55.0, 0.38),
            (82.5, 0.24),
            (110.0, 0.18),
            (165.0, 0.12),
            (220.0, 0.08)
        ]
        var phases = [Float](repeating: 0, count: harmonics.count)

        for i in 0..<Int(totalFrames) {
            let t = Float(i) / Float(sampleRate)
            let progress = Float(i) / Float(totalFrames)

            // Slow 1.5 Hz tremolo for breathing feel
            let tremolo = 1.0 + 0.07 * sin(2.0 * Float.pi * 1.5 * t)

            var sample: Float = 0
            for (hIdx, (freq, amp)) in harmonics.enumerated() {
                let phaseInc = 2.0 * Float.pi * freq / Float(sampleRate)
                sample += sin(phases[hIdx]) * amp
                phases[hIdx] += phaseInc
            }

            // Cross-fade fade-in / fade-out for seamless loop
            let fadeIn = min(progress * 5.0, 1.0)
            let fadeOut = min((1.0 - progress) * 5.0, 1.0)
            data[i] = sample * tremolo * fadeIn * fadeOut * volume * 0.28
        }
        return buf
    }
}
