import AppKit
import Foundation

enum CompanionSpriteCatalog {
    static func clips() -> [String: AnimationClip] {
        guard let atlas = loadAtlasFrames(named: "LizardCompanionSheet", frameCount: 52) else {
            return fallbackClips()
        }

        return [
            "idle_blink": AnimationClip(id: "idle_blink", frames: [atlas[0], atlas[1]], fps: 3),
            "sleep": AnimationClip(id: "sleep", frames: [atlas[2], atlas[3]], fps: 2),
            "code_mac": AnimationClip(id: "code_mac", frames: [atlas[4], atlas[5]], fps: 6),
            "code_terminal": AnimationClip(id: "code_terminal", frames: [atlas[6], atlas[7]], fps: 6),
            "code_cursor": AnimationClip(id: "code_cursor", frames: [atlas[8], atlas[9]], fps: 6),
            "music_headphones": AnimationClip(id: "music_headphones", frames: [atlas[10], atlas[11], atlas[12]], fps: 7),
            "battery_worry": AnimationClip(id: "battery_worry", frames: [atlas[13], atlas[14]], fps: 4),
            "meeting_wave": AnimationClip(id: "meeting_wave", frames: [atlas[15], atlas[16]], fps: 5),
            "browse_think": AnimationClip(id: "browse_think", frames: [atlas[17], atlas[18]], fps: 4),
            "chat_talk": AnimationClip(id: "chat_talk", frames: [atlas[19], atlas[20]], fps: 5),

            // Expanded professional clip catalog for richer contextual reactions.
            "celebrate_fireworks": AnimationClip(id: "celebrate_fireworks", frames: [atlas[21], atlas[22], atlas[23]], fps: 7),
            "focus_deep": AnimationClip(id: "focus_deep", frames: [atlas[24], atlas[25]], fps: 4),
            "notify_ping": AnimationClip(id: "notify_ping", frames: [atlas[26], atlas[27]], fps: 6),
            "compile_wait": AnimationClip(id: "compile_wait", frames: [atlas[28], atlas[29]], fps: 3),
            "break_stretch": AnimationClip(id: "break_stretch", frames: [atlas[30], atlas[31]], fps: 3),
            "charge_recover": AnimationClip(id: "charge_recover", frames: [atlas[32], atlas[33]], fps: 4),
            "meeting_urgent": AnimationClip(id: "meeting_urgent", frames: [atlas[34], atlas[35]], fps: 6),

            "ai_assistant": AnimationClip(id: "ai_assistant", frames: [atlas[36], atlas[37]], fps: 4),
            "meeting_call": AnimationClip(id: "meeting_call", frames: [atlas[38], atlas[39]], fps: 4),
            "docs_write": AnimationClip(id: "docs_write", frames: [atlas[40], atlas[41]], fps: 3),
            "sheet_crunch": AnimationClip(id: "sheet_crunch", frames: [atlas[42], atlas[43]], fps: 3),
            "launch_fast": AnimationClip(id: "launch_fast", frames: [atlas[44], atlas[45]], fps: 6),
            "racing_watch": AnimationClip(id: "racing_watch", frames: [atlas[46], atlas[47]], fps: 6),
            "github_sync": AnimationClip(id: "github_sync", frames: [atlas[48], atlas[49]], fps: 4),
            "secure_shield": AnimationClip(id: "secure_shield", frames: [atlas[50], atlas[51]], fps: 3)
        ]
    }

    static func fallbackIcon() -> NSImage {
        if let atlas = loadAtlasFrames(named: "LizardCompanionSheet", frameCount: 52), let first = atlas.first {
            return first
        }
        let fallback = NSImage(size: NSSize(width: 24, height: 24))
        fallback.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 4, width: 20, height: 16)).fill()
        fallback.unlockFocus()
        return fallback
    }

    private static func fallbackClips() -> [String: AnimationClip] {
        let icon = fallbackIcon()
        return [
            "idle_blink": AnimationClip(id: "idle_blink", frames: [icon], fps: 1),
            "sleep": AnimationClip(id: "sleep", frames: [icon], fps: 1),
            "code_mac": AnimationClip(id: "code_mac", frames: [icon], fps: 1),
            "code_terminal": AnimationClip(id: "code_terminal", frames: [icon], fps: 1),
            "code_cursor": AnimationClip(id: "code_cursor", frames: [icon], fps: 1),
            "music_headphones": AnimationClip(id: "music_headphones", frames: [icon], fps: 1),
            "battery_worry": AnimationClip(id: "battery_worry", frames: [icon], fps: 1),
            "meeting_wave": AnimationClip(id: "meeting_wave", frames: [icon], fps: 1),
            "browse_think": AnimationClip(id: "browse_think", frames: [icon], fps: 1),
            "chat_talk": AnimationClip(id: "chat_talk", frames: [icon], fps: 1),
            "celebrate_fireworks": AnimationClip(id: "celebrate_fireworks", frames: [icon], fps: 1),
            "focus_deep": AnimationClip(id: "focus_deep", frames: [icon], fps: 1),
            "notify_ping": AnimationClip(id: "notify_ping", frames: [icon], fps: 1),
            "compile_wait": AnimationClip(id: "compile_wait", frames: [icon], fps: 1),
            "break_stretch": AnimationClip(id: "break_stretch", frames: [icon], fps: 1),
            "charge_recover": AnimationClip(id: "charge_recover", frames: [icon], fps: 1),
            "meeting_urgent": AnimationClip(id: "meeting_urgent", frames: [icon], fps: 1),
            "ai_assistant": AnimationClip(id: "ai_assistant", frames: [icon], fps: 1),
            "meeting_call": AnimationClip(id: "meeting_call", frames: [icon], fps: 1),
            "docs_write": AnimationClip(id: "docs_write", frames: [icon], fps: 1),
            "sheet_crunch": AnimationClip(id: "sheet_crunch", frames: [icon], fps: 1),
            "launch_fast": AnimationClip(id: "launch_fast", frames: [icon], fps: 1),
            "racing_watch": AnimationClip(id: "racing_watch", frames: [icon], fps: 1),
            "github_sync": AnimationClip(id: "github_sync", frames: [icon], fps: 1),
            "secure_shield": AnimationClip(id: "secure_shield", frames: [icon], fps: 1)
        ]
    }

    private static func loadAtlasFrames(named assetName: String, frameCount: Int) -> [NSImage]? {
        guard let image = NSImage(named: assetName) else { return nil }
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard frameCount > 0 else { return nil }

        let frameWidth = cg.width / frameCount
        guard frameWidth > 0 else { return nil }

        var frames: [NSImage] = []
        frames.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            let rect = CGRect(x: index * frameWidth, y: 0, width: frameWidth, height: cg.height)
            guard let cropped = cg.cropping(to: rect) else { continue }
            let frame = NSImage(cgImage: cropped, size: NSSize(width: frameWidth, height: cg.height))
            frame.isTemplate = false
            frames.append(frame)
        }

        return frames.count == frameCount ? frames : nil
    }
}
