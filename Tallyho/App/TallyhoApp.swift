import SwiftUI
import UserNotifications

@main
struct TallyhoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TallyStore.shared
    @State private var themes = ThemeManager.shared
    @State private var router = Router.shared
    @State private var wasInBackground = true
    @State private var hasBeenActive = false

    init() {
        AppSettings.register()
        LaunchOptions.apply()
        AppWiring.connect()
    }

    var body: some Scene {
        WindowGroup {
            ThemedRoot()
                .environment(store)
                .environment(themes)
                .environment(router)
                .onOpenURL { router.open($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                let fromBackground = wasInBackground
                wasInBackground = false
                store.reload()
                if hasBeenActive {
                    ThemeCrossfade.perform { themes.appBecameActive(fromBackground: fromBackground) }
                } else {
                    hasBeenActive = true
                    themes.appBecameActive(fromBackground: fromBackground)
                }
                AppWiring.pushToWatch()
                Haptics.prepare()
            case .background:
                wasInBackground = true
                store.flush()
            default:
                break
            }
        }
    }
}

/// Picks the light or dark version of the active theme and applies it to the whole app.
private struct ThemedRoot: View {
    @Environment(ThemeManager.self) private var themes
    /// With the appearance set to follow the device, nothing overrides this, so it is the device's setting.
    @Environment(\.colorScheme) private var deviceScheme

    var body: some View {
        let theme = themes.theme(forDevice: deviceScheme)
        RootView()
            .environment(\.theme, theme)
            .preferredColorScheme(themes.appearance.colorScheme)
            .tint(theme.actionColor)
    }
}

/// Connects the store, theme and watch so each change reaches everywhere.
@MainActor
enum AppWiring {
    private static var observer: NSObjectProtocol?

    static func connect() {
        TallyStore.shared.onChange = { pushToWatch() }
        ThemeManager.shared.onChange = { pushToWatch() }
        PhoneSync.shared.onCount = { id, reverse in
            TallyStore.shared.count(id, reverse: reverse)
        }
        PhoneSync.shared.onComplete = { id in
            TallyStore.shared.complete(id)
            TallyStore.shared.dismissUndo()
        }
        PhoneSync.shared.onSnapshotRequest = { pushToWatch() }
        PhoneSync.shared.activate()

        // Widgets and controls write the shared file from another process; reload when they do.
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            Task { @MainActor in TallyStore.shared.reload() }
        }, TallyFileStore.changedNotification as CFString, nil, .deliverImmediately)
    }

    static func pushToWatch() {
        let store = TallyStore.shared
        let tallies = store.homeTallies(showHidden: false)
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
            .prefix(40)
            .map { WatchTally($0, folderName: store.folder($0.folderID)?.displayName) }
        PhoneSync.shared.send(WatchSnapshot(themeID: ThemeManager.shared.active.id, tallies: Array(tallies), sentAt: Date()))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let idString = response.notification.request.content.userInfo["tallyID"] as? String,
              let id = UUID(uuidString: idString) else { return }
        await MainActor.run { Router.shared.openTally(id) }
    }
}

/// Launch arguments for screenshots: `-demo`, `-theme <id>`, `-screen <name>`, `-split`, `-ghost`.
/// Demo data lives in a temporary file, so real tallies are never touched.
@MainActor
enum LaunchOptions {
    static func apply() {
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        guard args.contains("-demo") else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tallyho-demo.json")
        TallyFileStore.overrideURL = url
        TallyFileStore.save(args.contains("-ghost") ? DemoData.withEmptyWaterFolder() : DemoData.make())
        TallyStore.shared.reload()
        UserDefaults.standard.set(args.contains("-split"), forKey: AppSettings.splitPanes)
        if let theme = value(after: "-theme") {
            ThemeManager.shared.force(theme)
            // Screenshots show a theme in its home appearance unless `-appearance light|dark` says otherwise.
            let home: ThemeAppearance = ThemeManager.shared.active.scheme == .dark ? .dark : .light
            ThemeManager.shared.appearance = value(after: "-appearance").flatMap(ThemeAppearance.init) ?? home
        }
        if let screen = value(after: "-screen") { Router.shared.openForScreenshot(screen) }
    }
}
