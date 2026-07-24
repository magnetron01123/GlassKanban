import AppKit

/// The physical half of moving a ticket — what the hand and ear get, where
/// the eye already gets the settle animation.
///
/// A real board answers every move twice: the card *thunks* onto the cork,
/// and your fingers feel it land. This is that answer at whisper level, and
/// deliberately nothing more: no fanfare, no confetti, no escalation. The
/// psychology the board leans on (goal gradient, streaks, the settle) works
/// because rewards stay small and certain — a big reward would make the
/// hundredth completion feel smaller than the first.
///
/// Two channels, two rules:
/// - **Haptic** on every real column change. It is the sense of the card
///   clicking into a slot, it is silent, and it only exists under the finger
///   that made the move (Force-Touch trackpads; a mouse simply feels
///   nothing). Completing steps up from `.alignment` to `.levelChange` — the
///   same vocabulary macOS itself uses for "something latched".
/// - **Sound** only on completion, and only if Settings allows it. Completion
///   is the one moment Personal Kanban actually celebrates; a tick on every
///   move would turn the board into an instrument. "Tink" at low volume is a
///   glass sound for a glass app — short, bright, gone.
enum MoveFeedback {

    /// Quiet enough to read as the board itself, not as a notification.
    private static let volume: Float = 0.3

    static func play(completed: Bool, soundEnabled: Bool) {
        NSHapticFeedbackManager.defaultPerformer.perform(
            completed ? .levelChange : .alignment,
            performanceTime: .default)
        guard completed, soundEnabled, let sound = NSSound(named: "Tink") else { return }
        sound.volume = volume
        sound.play()
    }
}
