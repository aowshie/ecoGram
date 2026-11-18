import Foundation
import UIKit
import AVFAudio
import SwiftSignalKit
import AyuSettings

public final class AyuKeepAlive {
    private let beginBackgroundTask: (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?
    private let endBackgroundTask: (UIBackgroundTaskIdentifier) -> Void
    private let updated: (Bool) -> Void

    private var player: AVAudioPlayer?
    private var isPlaying = false
    private var inForeground = true
    private var telegramAudioActive = false
    private var interrupted = false
    private var retryTimer: SwiftSignalKit.Timer?
    private var retryTask: UIBackgroundTaskIdentifier?
    private var observers: [NSObjectProtocol] = []

    public private(set) var isActive = false {
        didSet {
            if self.isActive != oldValue {
                self.updated(self.isActive)
            }
        }
    }

    public init(beginBackgroundTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?, endBackgroundTask: @escaping (UIBackgroundTaskIdentifier) -> Void, updated: @escaping (Bool) -> Void) {
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.updated = updated

        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self, let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: rawValue) else {
                return
            }
            self.handleInterruption(began: type == .began)
        }))
        self.observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.player = nil
            self.isPlaying = false
            self.apply()
        }))
        self.observers.append(center.addObserver(forName: AyuSettings.didChange, object: nil, queue: .main, using: { [weak self] _ in
            self?.updateWanted()
        }))
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.retryTimer?.invalidate()
    }

    public func update(inForeground: Bool) {
        guard self.inForeground != inForeground else {
            return
        }
        self.inForeground = inForeground
        if inForeground {
            self.interrupted = false
        }
        self.updateWanted()
    }

    public func update(telegramAudioActive: Bool) {
        guard self.telegramAudioActive != telegramAudioActive else {
            return
        }
        self.telegramAudioActive = telegramAudioActive
        self.apply()
    }

    private func updateWanted() {
        self.isActive = !self.inForeground && AyuSettings.shared.backgroundNotifications
        self.apply()
    }

    private func handleInterruption(began: Bool) {
        guard self.isActive else {
            return
        }
        if began {
            if self.telegramAudioActive {
                return
            }
            self.interrupted = true
            self.isPlaying = false
            self.scheduleRetry()
        } else {
            self.interrupted = false
            self.apply()
        }
    }

    private func apply() {
        let shouldPlay = self.isActive && !self.telegramAudioActive && !self.interrupted
        if shouldPlay {
            if !self.isPlaying {
                if self.start() {
                    self.stopRetry()
                } else {
                    self.scheduleRetry()
                }
            }
            return
        }
        if !self.interrupted || !self.isActive {
            self.stopRetry()
        }
        if self.isPlaying {
            self.player?.pause()
            self.isPlaying = false
            if !self.telegramAudioActive {
                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }
    }

    private func start() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return false
        }
        if self.player == nil {
            guard let player = try? AVAudioPlayer(data: AyuKeepAlive.silence()) else {
                return false
            }
            player.numberOfLoops = -1
            player.volume = 0.0
            player.prepareToPlay()
            self.player = player
        }
        guard let player = self.player, player.play() else {
            return false
        }
        self.isPlaying = true
        return true
    }

    private func scheduleRetry() {
        if self.retryTask == nil {
            var taskId: UIBackgroundTaskIdentifier?
            taskId = self.beginBackgroundTask("ecogram-keepalive", { [weak self] in
                guard let self, let current = self.retryTask, current == taskId else {
                    return
                }
                self.retryTask = nil
                self.endBackgroundTask(current)
            })
            self.retryTask = taskId
        }
        if self.retryTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                if !self.isActive || self.telegramAudioActive {
                    self.stopRetry()
                    return
                }
                if self.start() {
                    self.interrupted = false
                    self.stopRetry()
                }
            }, queue: Queue.mainQueue())
            self.retryTimer = timer
            timer.start()
        }
    }

    private func stopRetry() {
        self.retryTimer?.invalidate()
        self.retryTimer = nil
        if let retryTask = self.retryTask {
            self.retryTask = nil
            self.endBackgroundTask(retryTask)
        }
    }

    private static func silence() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize = sampleRate * 2
        var data = Data()
        func append32(_ value: UInt32) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 4))
        }
        func append16(_ value: UInt16) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 2))
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append32(16)
        append16(1)
        append16(1)
        append32(sampleRate)
        append32(sampleRate * 2)
        append16(2)
        append16(16)
        data.append(contentsOf: Array("data".utf8))
        append32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
