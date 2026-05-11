import Foundation
import Combine

@MainActor
final class PowerViewModel: ObservableObject {
    var event: some Publisher<PowerEvent, Never> { eventSubject }
    private let eventSubject = PassthroughSubject<PowerEvent, Never>()

    private let powerStateProvider: any PowerStateProviding
    private let batterySettings: BatterySettingsStore
    private var previousOnACPower: Bool
    private var previousBatteryLevel: Int
    private var lowPowerThreshold: Int
    private var fullPowerThreshold: Int
    private var cancellables = Set<AnyCancellable>()

    private var eventDebounceTask: Task<Void, Never>?

    init(
        powerService: any PowerStateProviding,
        batterySettings: BatterySettingsStore
    ) {
        self.powerStateProvider = powerService
        self.batterySettings = batterySettings
        self.previousOnACPower = powerService.onACPower
        self.previousBatteryLevel = powerService.batteryLevel
        self.lowPowerThreshold = batterySettings.lowPowerNotificationThreshold
        self.fullPowerThreshold = batterySettings.fullPowerNotificationThreshold
        setupThresholdBindings()
        setupBindings()
    }

    private func setupThresholdBindings() {
        batterySettings.$lowPowerNotificationThreshold
            .sink { [weak self] value in
                self?.lowPowerThreshold = value
            }
            .store(in: &cancellables)

        batterySettings.$fullPowerNotificationThreshold
            .sink { [weak self] value in
                self?.fullPowerThreshold = value
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        powerStateProvider.onPowerStateChange = { [weak self] onACPower, batteryLevel in
            guard let self else { return }

            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.handlePowerStateChange(onACPower: onACPower, batteryLevel: batteryLevel)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.handlePowerStateChange(onACPower: onACPower, batteryLevel: batteryLevel)
                }
            }
        }
    }

    private func handlePowerStateChange(onACPower: Bool, batteryLevel: Int) {
        var eventToSend: PowerEvent?

        if !previousOnACPower && onACPower {
            eventToSend = .charger
        }

        if previousBatteryLevel > lowPowerThreshold && batteryLevel <= lowPowerThreshold {
            eventToSend = .lowPower
        }

        if previousBatteryLevel < fullPowerThreshold && batteryLevel >= fullPowerThreshold {
            eventToSend = .fullPower
        }

        previousOnACPower = onACPower
        previousBatteryLevel = batteryLevel

        guard let eventToSend else { return }

        eventDebounceTask?.cancel()
        eventDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            eventSubject.send(eventToSend)
        }
    }
}
