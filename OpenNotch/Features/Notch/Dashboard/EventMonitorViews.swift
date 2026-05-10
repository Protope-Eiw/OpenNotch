import SwiftUI

struct ClickOutsideMonitor: NSViewRepresentable {
    let onClickOutside: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        context.coordinator.start(onClickOutside: onClickOutside)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClickOutside = onClickOutside
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onClickOutside: (() -> Void)?
        private var monitor: Any?

        func start(onClickOutside: @escaping () -> Void) {
            self.onClickOutside = onClickOutside
            monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                DispatchQueue.main.async { self?.onClickOutside?() }
            }
        }

        func stop() {
            if let m = monitor { NSEvent.removeMonitor(m) }
            monitor = nil
        }
    }
}

struct SwipeEventMonitor: NSViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        context.coordinator.start(left: onSwipeLeft, right: onSwipeRight)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSwipeLeft = onSwipeLeft
        context.coordinator.onSwipeRight = onSwipeRight
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onSwipeLeft: (() -> Void)?
        var onSwipeRight: (() -> Void)?
        private var monitor: Any?
        private var accumX: CGFloat = 0
        private var didFire = false

        func start(left: @escaping () -> Void, right: @escaping () -> Void) {
            onSwipeLeft = left
            onSwipeRight = right
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func stop() {
            if let m = monitor { NSEvent.removeMonitor(m) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            if event.phase == .began {
                accumX = 0
                didFire = false
            }
            if event.phase == .ended || event.phase == .cancelled {
                accumX = 0
                return event
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            guard abs(dx) > abs(dy) * 1.4, abs(dx) > 1 else { return event }

            if didFire { return nil }

            accumX += dx
            if accumX < -55 {
                didFire = true
                accumX = 0
                DispatchQueue.main.async { self.onSwipeLeft?() }
                return nil
            } else if accumX > 55 {
                didFire = true
                accumX = 0
                DispatchQueue.main.async { self.onSwipeRight?() }
                return nil
            }
            return event
        }
    }
}
