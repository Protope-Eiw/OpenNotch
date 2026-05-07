import SwiftUI

enum SettingsWindowLayout {
    static let width: CGFloat = 760
    static let height: CGFloat = 610
    static let sidebarWidth: CGFloat = 64
}

struct SettingsRootView: View {
    @ObservedObject var powerService: PowerService
    @ObservedObject var settingsViewModel: SettingsViewModel

    let notchViewModel: NotchViewModel
    let notchEventCoordinator: NotchEventCoordinator
    let bluetoothViewModel: BluetoothViewModel
    let networkViewModel: NetworkViewModel
    let downloadViewModel: DownloadViewModel
    let nowPlayingViewModel: NowPlayingViewModel
    let timerViewModel: TimerViewModel
    let lockScreenManager: LockScreenManager

    private let viewModel: SettingsRootViewModel
    @State private var selectedSection: SettingsRootViewModel.Section
    @State private var pendingResetSection: SettingsRootViewModel.Section?
    @State private var showDonation = false
    @StateObject private var permissionController = SettingsPermissionController()

    init(
        powerService: PowerService,
        settingsViewModel: SettingsViewModel,
        notchViewModel: NotchViewModel,
        notchEventCoordinator: NotchEventCoordinator,
        bluetoothViewModel: BluetoothViewModel,
        networkViewModel: NetworkViewModel,
        downloadViewModel: DownloadViewModel,
        nowPlayingViewModel: NowPlayingViewModel,
        timerViewModel: TimerViewModel,
        lockScreenManager: LockScreenManager
    ) {
        self.powerService = powerService
        self.settingsViewModel = settingsViewModel
        self.notchViewModel = notchViewModel
        self.notchEventCoordinator = notchEventCoordinator
        self.bluetoothViewModel = bluetoothViewModel
        self.networkViewModel = networkViewModel
        self.downloadViewModel = downloadViewModel
        self.nowPlayingViewModel = nowPlayingViewModel
        self.timerViewModel = timerViewModel
        self.lockScreenManager = lockScreenManager
        let rootViewModel = SettingsRootViewModel(
            settingsViewModel: settingsViewModel,
            notchViewModel: notchViewModel,
            notchEventCoordinator: notchEventCoordinator,
            bluetoothViewModel: bluetoothViewModel,
            powerService: powerService,
            networkViewModel: networkViewModel,
            downloadViewModel: downloadViewModel,
            nowPlayingViewModel: nowPlayingViewModel,
            timerViewModel: timerViewModel,
            lockScreenManager: lockScreenManager
        )
        self.viewModel = rootViewModel
        _selectedSection = State(initialValue: rootViewModel.initialSelection())
    }

    private func localized(_ key: String, fallback: String? = nil) -> String {
        settingsViewModel.application.appLanguage.locale.dn(key, fallback: fallback)
    }

    var body: some View {
        HStack(spacing: 0) {
            iconSidebar
            Divider()
            contentArea
        }
        .frame(width: SettingsWindowLayout.width, height: SettingsWindowLayout.height)
        .alert(item: $pendingResetSection) { section in
            Alert(
                title: Text(
                    String(
                        format: localized("settings.reset.title"),
                        localized(section.titleKey, fallback: section.fallbackTitle)
                    )
                ),
                message: Text(localized("settings.reset.message")),
                primaryButton: .destructive(Text(localized("settings.reset.action"))) {
                    viewModel.reset(section)
                },
                secondaryButton: .cancel(Text(localized("common.cancel")))
            )
        }
        .accessibilityIdentifier("settings.root")
        .environment(\.locale, settingsViewModel.application.appLanguage.locale)
        .preferredColorScheme(settingsViewModel.application.appearanceMode.preferredColorScheme)
    }

    // MARK: - Icon Sidebar

    private var iconSidebar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 4) {
                ForEach(SettingsRootViewModel.Section.allCases) { section in
                    sidebarIconButton(for: section)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Divider()
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            Button {
                showDonation.toggle()
            } label: {
                Image(systemName: showDonation ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(showDonation ? .pink : Color.secondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            .popover(isPresented: $showDonation, arrowEdge: .trailing) {
                DonationView()
            }
        }
        .frame(width: SettingsWindowLayout.sidebarWidth)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarIconButton(for section: SettingsRootViewModel.Section) -> some View {
        let isSelected = selectedSection == section
        return Button {
            selectedSection = section
            viewModel.persistSelection(section)
        } label: {
            Group {
                if let imageName = section.imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 40, height: 40)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .help(localized(section.titleKey, fallback: section.fallbackTitle))
        .accessibilityIdentifier("settings.sidebar.\(section.rawValue)")
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            contentHeader
            Divider()
            detailView(for: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier(selectedSection.accessibilityIdentifier)
        }
    }

    private var contentHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(selectedSection.titleKey, fallback: selectedSection.fallbackTitle))
                    .font(.system(size: 15, weight: .semibold))
                Text(localized(selectedSection.subtitleKey, fallback: selectedSection.fallbackSubtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.canReset(selectedSection) {
                Button {
                    pendingResetSection = selectedSection
                } label: {
                    Text(localized("settings.reset.action", fallback: "Reset"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.background)
    }

    // MARK: - Detail View

    @ViewBuilder
    private func detailView(for section: SettingsRootViewModel.Section) -> some View {
        switch section {
        case .general:
            GeneralSettingsView(
                applicationSettings: settingsViewModel.application
            )

        case .permissions:
            PermissionsSettingsView(
                permissionController: permissionController,
                applicationSettings: settingsViewModel.application
            )

        case .notch:
            NotchSettingsView(
                powerService: powerService,
                applicationSettings: settingsViewModel.application
            )

        case .interface:
            InterfaceSettingsView(applicationSettings: settingsViewModel.application)

        case .media:
            MediaSettingsView(
                mediaSettings: settingsViewModel.mediaAndFiles,
                applicationSettings: settingsViewModel.application
            )

        case .connectivity:
            ConnectivitySettingsView(
                connectivitySettings: settingsViewModel.connectivity,
                applicationSettings: settingsViewModel.application
            )

        case .system:
            SystemSettingsView(
                batterySettings: settingsViewModel.battery,
                hudSettings: settingsViewModel.hud,
                mediaSettings: settingsViewModel.mediaAndFiles,
                screenRecordingSettings: settingsViewModel.screenRecording,
                applicationSettings: settingsViewModel.application
            )

        case .lockScreen:
            LockScreenSettingsView(
                settings: settingsViewModel.lockScreen,
                applicationSettings: settingsViewModel.application
            )

        #if DEBUG
        case .debug:
            DebugSettingsView(viewModel: viewModel.debugViewModel)
        #endif
        }
    }
}
