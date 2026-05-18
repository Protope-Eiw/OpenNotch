//
//  NowPlayingMinimalNotchView.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct NowPlayingMinimalNotchView: View {
    @Environment(\.notchScale) var scale
    @Environment(\.notchHasHardwareNotch) private var hasHardwareNotch
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: "Nothing Playing",
            artist: "Nothing artists",
            album: "",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot

        timelineContent(snapshot: snapshot)
    }

    private func timelineContent(snapshot: NowPlayingSnapshot) -> some View {
        HStack(spacing: 8.scaled(by: scale)) {
            ArtworkView(nowPlayingViewModel: nowPlayingViewModel, width: 24, height: 24, cornerRadius: 5)

            if !hasHardwareNotch, nowPlayingViewModel.snapshot != nil, snapshot.hasVisibleMetadata {
                CompactNowPlayingMetadataView(snapshot: snapshot)
                    .frame(maxWidth: 170.scaled(by: scale), alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                Spacer(minLength: 0)
            }

            LightweightNowPlayingEqualizerView(
                isPlaying: snapshot.isPlaying,
                color: nowPlayingViewModel.artworkPalette.equalizerBaseColor
            )
            .frame(width: 18, height: 16)
        }
        .padding(.horizontal, 14.scaled(by: scale))
    }
}

struct CompactNowPlayingMetadataView: View {
    let snapshot: NowPlayingSnapshot

    private var title: String {
        snapshot.title.trimmed.isEmpty ? "Unknown Track" : snapshot.title.trimmed
    }

    private var artist: String {
        snapshot.artist.trimmed.isEmpty ? "Unknown Artist" : snapshot.artist.trimmed
    }

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            AnimatedCompactLine(
                text: title,
                font: .system(size: 10, weight: .semibold),
                color: .white.opacity(0.9),
                alignment: .center
            )

            AnimatedCompactLine(
                text: artist,
                font: .system(size: 9, weight: .medium),
                color: .white.opacity(0.5),
                alignment: .center
            )
        }
        .frame(height: 24, alignment: .center)
        .clipped()
    }
}

struct CompactNowPlayingIdleTextView: View {
    let text: String

    var body: some View {
        AnimatedCompactLine(
            text: text,
            font: .system(size: 11, weight: .medium),
            color: .white.opacity(0.62),
            alignment: .center
        )
        .frame(height: 24)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipped()
    }
}

struct AnimatedCompactLine: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: Alignment = .leading

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    private let travel: CGFloat = 18
    private let cycleDuration: TimeInterval = 7

    private var shouldAnimate: Bool {
        textWidth > containerWidth + 2
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .offset(x: shouldAnimate ? xOffset(at: timeline.date) : 0)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                    .clipped()
                    .background {
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .hidden()
                            .readWidth { textWidth = $0 }
                    }
            }
            .onAppear { containerWidth = geometry.size.width }
            .onChange(of: geometry.size.width) { _, width in
                containerWidth = width
            }
        }
    }

    private func xOffset(at date: Date) -> CGFloat {
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        let eased = 0.5 - 0.5 * cos(progress * 2 * .pi)
        return -travel * CGFloat(eased)
    }
}

private struct CompactLineWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CompactLineWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(CompactLineWidthKey.self, perform: onChange)
    }
}
