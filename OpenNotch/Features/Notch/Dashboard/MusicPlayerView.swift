import SwiftUI

struct MusicPlayerView: View {
    let snapshot: NowPlayingSnapshot
    let artwork: NSImage?
    let onPlayPause: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSkipBack: () -> Void
    let onSkipForward: () -> Void

    @AppStorage(AppStorageKeys.Music.showSkipButtons) private var showSkipButtons = true
    @AppStorage(AppStorageKeys.Music.showVisualizer)  private var showVisualizer  = true

    @State private var scrubProgress: Double? = nil
    @State private var isDragging = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: snapshot.isPlaying ? 0.5 : 60)) { context in
            let elapsed = snapshot.elapsedTime(at: context.date)
            let progress = snapshot.duration > 0 ? elapsed / snapshot.duration : 0
            content(elapsed: elapsed, progress: scrubProgress ?? progress)
        }
    }

    private func content(elapsed: TimeInterval, progress: Double) -> some View {
        HStack(spacing: 14) {
            artworkView

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.title.isEmpty ? "Unknown" : snapshot.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(snapshot.artist.isEmpty ? "\u{2013}" : snapshot.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                        if showVisualizer {
                            AudioSpectrumView(isPlaying: snapshot.isPlaying)
                                .frame(width: 16, height: 10)
                                .opacity(snapshot.isPlaying ? 1 : 0.3)
                                .animation(.easeInOut(duration: 0.3), value: snapshot.isPlaying)
                        }
                    }
                }

                Spacer(minLength: 6)

                VStack(spacing: 5) {
                    progressBar(progress: progress)
                    HStack {
                        Text(timeString(elapsed))
                        Spacer()
                        Text(timeString(snapshot.duration))
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                }

                Spacer(minLength: 8)

                HStack(spacing: showSkipButtons ? 14 : 32) {
                    if showSkipButtons {
                        Button(action: onSkipBack) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onPrev) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: onPlayPause) {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if showSkipButtons {
                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artworkView: some View {
        ZStack {
            if let img = artwork {
                Image(nsImage: img)
                    .resizable()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(x: 1.4, y: 1.5)
                    .rotationEffect(.degrees(92))
                    .blur(radius: 30)
                    .opacity(snapshot.isPlaying ? 0.5 : 0)
            }

            Group {
                if let img = artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.white.opacity(0.07)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(snapshot.isPlaying ? 1.0 : 0.87)

            Rectangle()
                .fill(Color.black)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: .infinity)
                .blur(radius: 50)
                .opacity(snapshot.isPlaying ? 0 : 0.6)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.45), value: snapshot.isPlaying)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(Color.white.opacity(isDragging ? 1.0 : 0.8))
                    .frame(width: max(4, geo.size.width * CGFloat(min(progress, 1))))
            }
            .frame(height: isDragging ? 7 : 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 20)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        withAnimation { isDragging = true }
                        scrubProgress = max(0, min(1, Double(val.location.x / geo.size.width)))
                    }
                    .onEnded { val in
                        let p = max(0, min(1, Double(val.location.x / geo.size.width)))
                        onSeek(p * snapshot.duration)
                        scrubProgress = nil
                        withAnimation { isDragging = false }
                    }
            )
        }
        .frame(height: 10)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let t = max(0, t)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
