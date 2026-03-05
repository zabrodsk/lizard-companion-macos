import AppKit
import Combine
import Foundation

@MainActor
final class SpriteAnimator: ObservableObject {
    @Published private(set) var currentImage: NSImage

    private var timer: Timer?
    private var currentClip: AnimationClip
    private var frameIndex = 0
    private var pendingClip: AnimationClip?
    private var lastClipSwitch = Date.distantPast
    private var speedMultiplier: Double = 1

    init(initialClip: AnimationClip) {
        self.currentClip = initialClip
        self.currentImage = initialClip.frames.first ?? CompanionSpriteCatalog.fallbackIcon()
        startTimer(for: initialClip)
    }

    func setClip(_ clip: AnimationClip, debounce: TimeInterval = 0.25) {
        guard clip.id != currentClip.id else { return }

        let now = Date()
        if now.timeIntervalSince(lastClipSwitch) < debounce {
            pendingClip = clip
            DispatchQueue.main.asyncAfter(deadline: .now() + debounce) { [weak self] in
                guard let self, let pending = self.pendingClip else { return }
                self.pendingClip = nil
                self.forceSetClip(pending)
            }
            return
        }

        forceSetClip(clip)
    }

    func setSpeedMultiplier(_ multiplier: Double) {
        let newValue = max(0.2, min(2.0, multiplier))
        guard abs(newValue - speedMultiplier) > 0.01 else { return }
        speedMultiplier = newValue
        startTimer(for: currentClip)
    }

    private func forceSetClip(_ clip: AnimationClip) {
        currentClip = clip
        frameIndex = 0
        currentImage = clip.frames.first ?? CompanionSpriteCatalog.fallbackIcon()
        lastClipSwitch = Date()
        startTimer(for: clip)
    }

    private func startTimer(for clip: AnimationClip) {
        timer?.invalidate()
        let effectiveFPS = max(1, clip.fps * speedMultiplier)
        let interval = max(0.05, 1.0 / effectiveFPS)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func advanceFrame() {
        guard !currentClip.frames.isEmpty else {
            currentImage = CompanionSpriteCatalog.fallbackIcon()
            return
        }

        frameIndex = (frameIndex + 1) % currentClip.frames.count
        currentImage = currentClip.frames[frameIndex]
    }
}
