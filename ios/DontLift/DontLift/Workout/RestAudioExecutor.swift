import AVFoundation
import Foundation
import os

/// 所有播放器和 audio session 操作只在此串行队列执行。
/// 取消代数单独加锁，关闭声音无需等待解码就能使排队的播放失效。
nonisolated final class RestAudioExecutor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dontlift.rest.audio", qos: .userInitiated)
    private let generation = OSAllocatedUnfairLock(initialState: 0)
    private var player: AVAudioPlayer?
    private var release: DispatchWorkItem?
    private var sessionActive = false

    func prepare() {
        queue.async { self.preparePlayer() }
    }

    func play() {
        let token = generation.withLock { $0 }
        queue.async {
            guard self.isCurrent(token) else { return }
            self.preparePlayer()
            guard self.isCurrent(token), let player = self.player else { return }
            self.release?.cancel()
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.duckOthers, .mixWithOthers])
            try? session.setActive(true)
            self.sessionActive = true
            guard self.isCurrent(token) else { self.stopPlayer(); return }
            player.currentTime = 0
            player.play()
            let release = DispatchWorkItem { [weak self] in
                guard let self, self.isCurrent(token) else { return }
                self.stopPlayer()
            }
            self.release = release
            self.queue.asyncAfter(deadline: .now() + player.duration + 0.3, execute: release)
        }
    }

    func stop() {
        generation.withLock { $0 += 1 }
        queue.async { self.stopPlayer() }
    }

    private func isCurrent(_ token: Int) -> Bool {
        generation.withLock { $0 == token }
    }

    private func preparePlayer() {
        dispatchPrecondition(condition: .onQueue(queue))
        assert(!Thread.isMainThread)
        guard player == nil else { return }
        WorkoutPerformanceMonitor.measure("audio.prepare") {
            if let url = Bundle.main.url(forResource: "rest_complete", withExtension: "caf") {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = 1
                player?.prepareToPlay()
            }
        }
    }

    private func stopPlayer() {
        release?.cancel()
        release = nil
        player?.stop()
        player?.currentTime = 0
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }
}
