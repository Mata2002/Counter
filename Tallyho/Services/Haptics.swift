import AudioToolbox
import CoreHaptics
import UIKit

/// Taps, the goal rumble, and an optional click sound.
@MainActor
enum Haptics {
    private static let tapGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static var engine: CHHapticEngine?

    private static var defaults: UserDefaults { .standard }

    static func prepare() {
        tapGenerator.prepare()
        softGenerator.prepare()
    }

    /// Every count. Forward taps feel crisp; taking one back feels soft.
    static func count(reverse: Bool = false) {
        if defaults.bool(forKey: AppSettings.hapticEachTap) {
            (reverse ? softGenerator : tapGenerator).impactOccurred(intensity: reverse ? 0.6 : 0.9)
        }
        if defaults.bool(forKey: AppSettings.tapSound) {
            AudioServicesPlaySystemSound(1104)
        }
    }

    static func light() {
        softGenerator.impactOccurred(intensity: 0.5)
    }

    /// A rising rumble you can feel in a pocket, plus a real vibration if you asked for it.
    static func goalReached() {
        guard defaults.bool(forKey: AppSettings.vibrateAtGoal) else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        playCrescendo()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private static func playCrescendo() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            if engine == nil {
                let fresh = try CHHapticEngine()
                fresh.resetHandler = { [weak fresh] in try? fresh?.start() }
                engine = fresh
            }
            try engine?.start()
            var events: [CHHapticEvent] = []
            // Three quick taps getting stronger, then a long swell.
            for (i, t) in [0.0, 0.12, 0.24].enumerated() {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5 + Float(i) * 0.2),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ], relativeTime: t))
            }
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
            ], relativeTime: 0.4, duration: 0.6))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
            ], relativeTime: 1.05))
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
