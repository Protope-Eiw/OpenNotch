//
//  ScreenRecordingContent.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/30/26.
//

import SwiftUI

enum ScreenRecordingEvent: Equatable {
    case started
    case stopped
}

struct ScreenRecordingContent: NotchContentProtocol {
    let id = NotchContentRegistry.ScreenRecording.active.id
    var priority: Int { NotchContentRegistry.ScreenRecording.active.priority }
    var strokeColor: Color { .white.opacity(0.2) }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        return .init(width: baseWidth + 60, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(ScreenRecordingView())
    }
}
