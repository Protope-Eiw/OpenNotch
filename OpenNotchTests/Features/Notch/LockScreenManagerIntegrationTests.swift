import XCTest
@testable import OpenNotch

@MainActor
final class LockScreenManagerIntegrationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: LockScreenSettings.soundKey)
    }

    func testLockAndUnlockTransitionsPlayExpectedSounds() async {
        let service = FakeLockScreenMonitoringService()
        let soundPlayer = FakeLockScreenSoundPlayer()
        let manager = LockScreenManager(
            service: service,
            soundPlayer: soundPlayer,
            unlockCollapseDelay: 0.05,
            idleResetDelay: 0.05
        )

        manager.startMonitoring()

        service.publish(isLocked: true)
        service.publish(isLocked: true)
        service.publish(isLocked: false)
        service.publish(isLocked: false)

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                soundPlayer.playedSounds == [.lock, .unlock] &&
                !manager.isLocked &&
                !manager.isLockIdle
            }
        }

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                manager.isLockIdle && manager.event == .stopped
            }
        }
    }

    func testLockAndUnlockTransitionsDoNotPlaySoundsWhenDisabled() async {
        UserDefaults.standard.set(false, forKey: LockScreenSettings.soundKey)

        let service = FakeLockScreenMonitoringService()
        let soundPlayer = FakeLockScreenSoundPlayer()
        let manager = LockScreenManager(
            service: service,
            soundPlayer: soundPlayer,
            unlockCollapseDelay: 0.05,
            idleResetDelay: 0.05
        )

        manager.startMonitoring()

        service.publish(isLocked: true)
        service.publish(isLocked: false)

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                soundPlayer.playedSounds.isEmpty &&
                !manager.isLocked &&
                !manager.isLockIdle
            }
        }

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                manager.isLockIdle && manager.event == .stopped
            }
        }
    }
}
