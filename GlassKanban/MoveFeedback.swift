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
///   move would turn the board into an instrument. The chime is the app's
///   own (`CompletionChime.wav`), not a system sound: every sound in
///   /System/Library/Sounds doubles as an *alert* somewhere on macOS —
///   "Tink" was tried and read as a warning, not a reward. This one is two
///   soft glass notes a fifth apart, rising, because rising says done-and-
///   good where a single percussive hit says look-here.
enum MoveFeedback {

    /// Quiet enough to read as the board itself, not as a notification.
    /// The sample is already mastered soft; this trims it into ambience.
    private static let volume: Float = 0.6

    static func play(completed: Bool, soundEnabled: Bool) {
        NSHapticFeedbackManager.defaultPerformer.perform(
            completed ? .levelChange : .alignment,
            performanceTime: .default)
        // No fallback to a system sound if the resource is missing: silence
        // is closer to the design than an alert noise would be.
        guard completed, soundEnabled, let sound = NSSound(named: "CompletionChime") else { return }
        sound.volume = volume
        sound.play()
    }
}
