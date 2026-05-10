import SwiftUI

struct DropSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore

    private var isDefaultStrokeLocked: Bool {
        true
    }
    
    @ViewBuilder var cards: some View {
        dragAndDropActivity
        dragAndDropMode
    }

    var body: some View {
        SettingsPageScrollView { cards }
    }
    
    private var dragAndDropActivity: some View {
        SettingsCard(title: localized("Drag&Drop activity")) {
            SettingsToggleRow(
                title: localized("Drag&Drop live activity"),
                description: localized("Show AirDrop and Tray targets when you drag files over the notch."),
                systemImage: "tray.and.arrow.down.fill",
                color: .blue,
                isOn: $mediaSettings.isDragAndDropLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.drop"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)

            SettingsToggleRow(
                title: localized("Tray live activity"),
                description: localized("Show the pinned file tray after files are dropped into Tray."),
                systemImage: "tray.full.fill",
                color: .black,
                isOn: $mediaSettings.isTrayLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.drop.tray"
            )
        }
    }

    private var dragAndDropMode: some View {
        SettingsCard(title: localized("Drag&Drop target")) {
            SettingsNotchPreview(
                width: dragAndDropPreviewNotchWidth,
                height: 148,
                previewHeight: 166,
                topCornerRadius: 24,
                bottomCornerRadius: 36,
                lightBackgroundImage: Image("backgroundLight"),
                darkBackgroundImage: Image("backgroundDark")
            ) {
                dragAndDropPreviewContent
            }

            SettingsDivider()

            SettingsMenuRow(
                title: localized("Target mode"),
                description: localized("Choose which target appears while files are dragged over the notch."),
                options: Array(DragAndDropActivityMode.allCases),
                optionTitle: { localized($0.title) },
                accessibilityIdentifier: "settings.activities.live.drop.mode",
                selection: $mediaSettings.dragAndDropActivityMode
            )
            
            SettingsDivider()

            SettingsStrokeToggleRow(
                title: localized("Default stroke"),
                description: localized("Use the standard white notch stroke instead of the Drag&Drop accent stroke."),
                isOn: $mediaSettings.isDragAndDropDefaultStrokeEnabled,
                accessibilityIdentifier: "settings.activities.live.drop.defaultStroke"
            )
            .disabled(isDefaultStrokeLocked)
            .opacity(isDefaultStrokeLocked ? 0.5 : 1)
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: localized("Motion animation"),
                description: localized("Play animation of cell movement when hovering a file over an area."),
                systemImage: "cursorarrow.motionlines",
                color: .pink,
                isOn: $mediaSettings.isDropMotionAnimationEnabled,
                accessibilityIdentifier: "settings.activities.live.drop.motionAnimation"
            )
        }
    }

    private var dragAndDropPreviewNotchWidth: CGFloat {
        mediaSettings.dragAndDropActivityMode == .combined ? 460 : 280
    }

    @ViewBuilder
    private var dragAndDropPreviewContent: some View {
        VStack {
            Spacer()

            HStack(spacing: AirDropDropZoneMetrics.combinedSpacing) {
                if mediaSettings.dragAndDropActivityMode.showsAirDrop {
                    dragAndDropPreviewTarget(.airDrop)
                }

                if mediaSettings.dragAndDropActivityMode.showsTray {
                    dragAndDropPreviewTarget(.tray)
                }
            }
            .frame(height: AirDropDropZoneMetrics.height)
        }
        .padding(.horizontal, AirDropDropZoneMetrics.horizontalPadding)
        .padding(.vertical, AirDropDropZoneMetrics.verticalPadding)
    }

    private var dragAndDropPreviewStrokeColor: Color {
        return .clear
    }

    private func dragAndDropPreviewTarget(_ target: DragAndDropTarget) -> some View {
        DragAndDropDropZoneContent(target: target, isTargeted: false)
            .frame(maxWidth: .infinity)
    }
    
    private func localized(_ key: String, fallback: String? = nil) -> String {
        appearanceSettings.appLanguage.locale.dn(key, fallback: fallback ?? key)
    }
}
