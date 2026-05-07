//
//  NotchPressModifier.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 2/14/26.
//

internal import AppKit
import SwiftUI

struct NotchCustomScaleModifier: ViewModifier {
    @ObservedObject var notchViewModel: NotchViewModel
    @Binding var isPressed: Bool
    
    @State private var pendingExpansionToken: UUID?
    @State private var initialPressLocation: CGPoint?
    @State private var isPressValidForTap = false
    @State private var didCompleteHoldAction = false

    let baseSize: CGSize

    private let tapMovementTolerance: CGFloat = 8
    
    func body(content: Content) -> some View {
        pressableContent(content)
    }
}

private extension NotchCustomScaleModifier {
    func pressableContent(_ content: Content) -> some View {
        let hitBounds = CGRect(origin: .zero, size: baseSize)

        return content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !notchViewModel.isActivityPresentationHidden,
                              !notchViewModel.notchModel.isPresentingExpandedLiveActivity else {
                            resetPressState()
                            return
                        }

                        let isInsideBounds = hitBounds.contains(value.location)

                        guard isInsideBounds else {
                            isPressValidForTap = false
                            resetPressState()
                            return
                        }

                        if !isPressed {
                            isPressed = true
                            initialPressLocation = value.location
                            isPressValidForTap = true
                            didCompleteHoldAction = false
                        }

                        if let initialPressLocation,
                           distance(from: initialPressLocation, to: value.location) > tapMovementTolerance {
                            isPressValidForTap = false
                            pendingExpansionToken = nil
                        }

                        if isPressValidForTap {
                            scheduleExpansionIfNeeded()
                        }
                    }
                    .onEnded { value in
                        guard !notchViewModel.isActivityPresentationHidden,
                              !notchViewModel.notchModel.isPresentingExpandedLiveActivity else {
                            resetPressState()
                            didCompleteHoldAction = false
                            return
                        }

                        let isValidPress = hitBounds.contains(value.location) &&
                        isPressValidForTap &&
                        !didCompleteHoldAction

                        resetPressState()

                        if notchViewModel.shouldExpandActiveContentOnClick && isValidPress {
                            notchViewModel.handleActiveContentTap()
                        } else if isValidPress {
                            notchViewModel.openActiveWindowLink()
                        }

                        didCompleteHoldAction = false
                    }
            )
            .onDisappear {
                resetPressState()
                didCompleteHoldAction = false
            }
    }

    private func performPressHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func scheduleExpansionIfNeeded() {
        guard pendingExpansionToken == nil,
              notchViewModel.shouldExpandActiveContentOnPressAndHold else {
            return
        }

        let token = UUID()
        let holdToExpandDelay = notchViewModel.notchPressHoldDuration
        pendingExpansionToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + holdToExpandDelay) {
            guard pendingExpansionToken == token,
                  isPressed,
                  notchViewModel.shouldExpandActiveContentOnPressAndHold,
                  !notchViewModel.notchModel.isPresentingExpandedLiveActivity else {
                return
            }

            pendingExpansionToken = nil
            didCompleteHoldAction = true
            performPressHaptic()
            resetPressState()
            notchViewModel.handleActiveContentTap()
        }
    }

    private func resetPressState() {
        pendingExpansionToken = nil
        initialPressLocation = nil
        isPressValidForTap = false

        if isPressed {
            isPressed = false
        }
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let xDistance = end.x - start.x
        let yDistance = end.y - start.y

        return sqrt((xDistance * xDistance) + (yDistance * yDistance))
    }
}
