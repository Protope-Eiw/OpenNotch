import Combine
import SwiftUI

@MainActor
final class PomodoroViewModel: ObservableObject {
    enum PomodoroState { case idle, running, paused }
    enum PomodoroPhase { case work, shortBreak }

    @Published private(set) var state: PomodoroState = .idle
    @Published private(set) var phase: PomodoroPhase = .work
    @Published private(set) var timeRemaining: Int = 25 * 60

    private var countdownTask: Task<Void, Never>?

    private var workMinutes: Int {
        max(UserDefaults.standard.integer(forKey: AppStorageKeys.Overview.pomodoroDuration), 1)
    }

    var timeString: String { String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60) }
    var phaseTotalSeconds: Int { phase == .work ? workMinutes * 60 : 5 * 60 }

    init() {
        timeRemaining = workMinutes * 60
    }

    deinit {
        countdownTask?.cancel()
    }

    func toggleRunning() {
        switch state {
        case .idle:
            timeRemaining = workMinutes * 60
            state = .running
            startCountdown()
        case .running:
            state = .paused
            countdownTask?.cancel()
        case .paused:
            state = .running
            startCountdown()
        }
    }

    func adjustTime(minutes: Int) {
        timeRemaining = max(0, timeRemaining + minutes * 60)
    }

    func syncWorkMinutes() {
        timeRemaining = workMinutes * 60
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        state = .idle
        phase = .work
        timeRemaining = workMinutes * 60
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled, timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            if phase == .work {
                phase = .shortBreak
                timeRemaining = 5 * 60
                startCountdown()
            } else {
                phase = .work
                state = .idle
                timeRemaining = workMinutes * 60
            }
        }
    }
}
