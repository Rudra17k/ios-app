#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

final class HapticsManager: ObservableObject {
    static let shared = HapticsManager()

    @AppStorage("enableHaptics") var isHapticsEnabled: Bool = true

    private init() {}

    func lightFeedback() {
        #if canImport(UIKit)
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    func mediumFeedback() {
        #if canImport(UIKit)
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    func successFeedback() {
        #if canImport(UIKit)
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    func milestoneCelebration() {
        #if canImport(UIKit)
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard self?.isHapticsEnabled == true else { return }
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred()
        }
        #endif
    }

    func warningFeedback() {
        #if canImport(UIKit)
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
}
