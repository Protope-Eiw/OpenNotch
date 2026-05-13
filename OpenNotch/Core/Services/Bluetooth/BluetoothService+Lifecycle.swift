import Foundation
import Combine
internal import AppKit
import IOBluetooth

extension BluetoothService {
    // MARK: - Setup Methods

    func setupBluetoothObservers() {
        #if DEBUG
        print("🎧 [BluetoothAudioManager] Setting up Bluetooth observers...")
        #endif
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            self,
            selector: #selector(handleDeviceConnectedNotification(_:)),
            name: NSNotification.Name("IOBluetoothDeviceConnectedNotification"),
            object: nil
        )

        dnc.addObserver(
            self,
            selector: #selector(handleDeviceDisconnectedNotification(_:)),
            name: NSNotification.Name("IOBluetoothDeviceDisconnectedNotification"),
            object: nil
        )

        #if DEBUG

        print("🎧 [BluetoothAudioManager] ✅ Observers registered with DistributedNotificationCenter")

        #endif
    }

    func checkInitialDevices() {
        #if DEBUG
        print("🎧 [BluetoothAudioManager] Checking for initially connected devices...")
        #endif
        guard IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON else {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] ⚠️ Bluetooth is powered off - skipping initial check")
            #endif
            return
        }

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] No paired devices found")
            #endif
            return
        }

        let connectedAudioDevices = pairedDevices.filter { device in
            device.isConnected() && isAudioDevice(device)
        }

        #if DEBUG

        print("🎧 [BluetoothAudioManager] Found \(connectedAudioDevices.count) connected audio devices")

        #endif
        connectedDevices = connectedAudioDevices.compactMap { device in
            createBluetoothAudioDevice(from: device)
        }

        isBluetoothAudioConnected = !connectedDevices.isEmpty
        refreshBatteryLevelsForConnectedDevices()

        if let lastDevice = connectedDevices.last {
            lastConnectedDevice = lastDevice
            #if DEBUG
            print("🎧 [BluetoothAudioManager] ✅ Bluetooth audio connected: \(lastDevice.name)")
            #endif
        }
    }

    // MARK: - Device Event Handlers

    @objc
    func handleDeviceConnectedNotification(_ notification: Notification) {
        #if DEBUG
        print("🎧 [BluetoothAudioManager] 📡 Device connection notification received")
        #endif
        checkForNewlyConnectedDevices()
    }

    @objc
    func handleDeviceDisconnectedNotification(_ notification: Notification) {
        #if DEBUG
        print("🎧 [BluetoothAudioManager] 📡 Device disconnection notification received")
        #endif
        updateConnectedDevices()
    }

    func checkForNewlyConnectedDevices() {
        guard IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON else {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] ⚠️ Bluetooth is powered off - skipping device check")
            #endif
            return
        }

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return
        }

        let currentlyConnectedDevices = pairedDevices.filter { device in
            device.isConnected() && isAudioDevice(device)
        }

        for device in currentlyConnectedDevices {
            let address = device.addressString ?? "Unknown"

            if !connectedDevices.contains(where: { $0.address == address }) {
                #if DEBUG
                print("🎧 [BluetoothAudioManager] 🎉 New audio device connected: \(device.name ?? "Unknown")")
                #endif
                guard let audioDevice = createBluetoothAudioDevice(from: device) else {
                    continue
                }

                connectedDevices.append(audioDevice)
                lastConnectedDevice = audioDevice
                isBluetoothAudioConnected = true

                refreshBatteryLevelsForConnectedDevices()
                schedulePostConnectionBatteryRefreshes(for: audioDevice)

                if let refreshedDevice = connectedDevices.last {
                    showDeviceConnectedHUD(refreshedDevice)
                } else {
                    showDeviceConnectedHUD(audioDevice)
                }
            }
        }
    }

    func updateConnectedDevices() {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return
        }

        let currentlyConnectedAddresses = pairedDevices
            .filter { $0.isConnected() && isAudioDevice($0) }
            .compactMap { $0.addressString }

        let removedDevices = connectedDevices.filter { device in
            !currentlyConnectedAddresses.contains(device.address)
        }
        connectedDevices.removeAll { device in
            !currentlyConnectedAddresses.contains(device.address)
        }

        if !removedDevices.isEmpty {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] 👋 Audio device(s) disconnected")
            #endif
            removedDevices.forEach {
                cancelHUDBatteryWait(for: $0)
                cancelPostConnectionBatteryRefresh(for: $0)
            }
        }

        isBluetoothAudioConnected = !connectedDevices.isEmpty
        refreshBatteryLevelsForConnectedDevices()
    }

    func handleDeviceConnected(_ notification: Notification) {
        guard let device = notification.object as? IOBluetoothDevice else {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] ⚠️ Could not extract device from notification")
            #endif
            return
        }

        guard isAudioDevice(device) else {
            #if DEBUG
            print("🎧 [BluetoothAudioManager] Device is not an audio device, ignoring")
            #endif
            return
        }

        #if DEBUG

        print("🎧 [BluetoothAudioManager] 🎉 Audio device connected: \(device.name ?? "Unknown")")

        #endif
        guard let audioDevice = createBluetoothAudioDevice(from: device) else {
            return
        }

        if !connectedDevices.contains(where: { $0.address == audioDevice.address }) {
            connectedDevices.append(audioDevice)
        }

        lastConnectedDevice = audioDevice
        isBluetoothAudioConnected = true
        refreshBatteryLevelsForConnectedDevices()
        schedulePostConnectionBatteryRefreshes(for: audioDevice)
        showDeviceConnectedHUD(audioDevice)
    }

    func handleDeviceDisconnected(_ notification: Notification) {
        guard let device = notification.object as? IOBluetoothDevice else {
            return
        }

        guard isAudioDevice(device) else {
            return
        }

        #if DEBUG

        print("🎧 [BluetoothAudioManager] 👋 Audio device disconnected: \(device.name ?? "Unknown")")

        #endif
        let address = device.addressString ?? "Unknown"
        let removed = connectedDevices.filter { $0.address == address }
        connectedDevices.removeAll { $0.address == address }
        removed.forEach {
            cancelHUDBatteryWait(for: $0)
            cancelPostConnectionBatteryRefresh(for: $0)
        }
        isBluetoothAudioConnected = !connectedDevices.isEmpty
    }

    // MARK: - Cleanup

    func cleanup() {
        #if DEBUG
        print("🎧 [BluetoothAudioManager] Cleaning up observers...")
        #endif

        let dnc = DistributedNotificationCenter.default()
        dnc.removeObserver(self)
        observers.removeAll()
        cancellables.removeAll()
        hudBatteryWaitTasks.values.forEach { $0.cancel() }
        hudBatteryWaitTasks.removeAll()
        postConnectionBatteryRetryTasks.values.forEach { $0.cancel() }
        postConnectionBatteryRetryTasks.removeAll()
    }
}
