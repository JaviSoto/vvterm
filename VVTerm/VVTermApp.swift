//
//  VVTermApp.swift
//  VVTerm
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
import Foundation
#if os(iOS)
import Network
#endif

@main
struct VVTermApp: App {
    init() {
        if let currentHome = getenv("HOME"), !String(cString: currentHome).isEmpty {
            // Keep existing HOME when provided by the host environment.
        } else {
            let sandboxHome = NSHomeDirectory()
            let fallbackHome = sandboxHome.isEmpty ? "/tmp" : sandboxHome
            setenv("HOME", fallbackHome, 1)
        }
        TerminalDefaults.applyIfNeeded()
    }

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    #if os(iOS)
    @StateObject private var ghosttyApp = Ghostty.App(autoStart: false)
    #else
    @StateObject private var ghosttyApp = Ghostty.App()
    #endif
    @StateObject private var terminalThemeManager = TerminalThemeManager.shared
    @StateObject private var terminalAccessoryPreferencesManager = TerminalAccessoryPreferencesManager.shared

    // Welcome screen flag
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    // App language
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage(PrivacyModeSettings.enabledKey) private var privacyModeEnabled = false
    private let processArguments = Foundation.ProcessInfo.processInfo.arguments
    private let processEnvironment = Foundation.ProcessInfo.processInfo.environment

    // Terminal settings to watch for changes
    @AppStorage("terminalFontName") private var terminalFontName = "JetBrainsMono Nerd Font"
    @AppStorage("terminalFontSize") private var terminalFontSize = 8.0
    @AppStorage("terminalThemeName") private var terminalThemeName = "Aizen Dark"
    @AppStorage("terminalThemeNameLight") private var terminalThemeNameLight = "Aizen Light"
    @AppStorage("terminalUsePerAppearanceTheme") private var usePerAppearanceTheme = true

    private var activeCustomThemeVersionToken: String {
        let activeThemes = terminalThemeManager.customThemes.filter { !$0.isDeleted }
        let byName = Dictionary(
            activeThemes.map { ($0.name, $0) },
            uniquingKeysWith: { current, candidate in
                current.updatedAt >= candidate.updatedAt ? current : candidate
            }
        )

        let darkVersion = byName[terminalThemeName]?.updatedAt.timeIntervalSince1970 ?? 0
        let lightVersion = byName[terminalThemeNameLight]?.updatedAt.timeIntervalSince1970 ?? 0

        if usePerAppearanceTheme {
            return "\(darkVersion):\(lightVersion)"
        }

        return "\(darkVersion)"
    }

    private var isInputHarnessMode: Bool {
        processArguments.contains("--vvterm-input-harness")
            || processEnvironment["VVTERM_INPUT_HARNESS"] == "1"
    }

    private var isSSHHarnessMode: Bool {
        processArguments.contains("--vvterm-ssh-harness")
            || processEnvironment["VVTERM_SSH_HARNESS"] == "1"
    }

    private var shouldPresentWelcome: Bool {
        !hasSeenWelcome && !isInputHarnessMode && !isSSHHarnessMode
    }

    var body: some Scene {
        WindowGroup("", id: "main") {
            let appLocale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
            AppLockContainer {
                Group {
                    #if os(iOS)
                    Group {
                        if isInputHarnessMode {
                            InputHarnessView()
                        } else if isSSHHarnessMode {
                            SSHHarnessView()
                        } else {
                            iOSContentView()
                        }
                    }
                        .environmentObject(ghosttyApp)
                        .environmentObject(terminalThemeManager)
                        .environmentObject(terminalAccessoryPreferencesManager)
                        .modifier(AppearanceModifier())
                        .task(id: "\(terminalFontName)\(terminalFontSize)\(terminalThemeName)\(terminalThemeNameLight)\(usePerAppearanceTheme)\(activeCustomThemeVersionToken)") {
                            ghosttyApp.reloadConfig()
                        }
                        .sheet(isPresented: .init(
                            get: { shouldPresentWelcome },
                            set: { if !$0 { hasSeenWelcome = true } }
                        )) {
                            WelcomeView(hasSeenWelcome: $hasSeenWelcome)
                        }
                    #else
                    ContentView()
                        .environmentObject(ghosttyApp)
                        .environmentObject(terminalThemeManager)
                        .environmentObject(terminalAccessoryPreferencesManager)
                        .modifier(AppearanceModifier())
                        .task(id: "\(terminalFontName)\(terminalFontSize)\(terminalThemeName)\(terminalThemeNameLight)\(usePerAppearanceTheme)\(activeCustomThemeVersionToken)") {
                            ghosttyApp.reloadConfig()
                        }
                        .sheet(isPresented: .init(
                            get: { !hasSeenWelcome },
                            set: { if !$0 { hasSeenWelcome = true } }
                        )) {
                            WelcomeView(hasSeenWelcome: $hasSeenWelcome)
                        }
                    #endif
                }
                .environment(\.locale, appLocale)
                .environment(\.privacyModeEnabled, privacyModeEnabled)
                .onAppear {
                    AppLanguage.applySelection(appLanguage)
                }
                .onChange(of: appLanguage) { newValue in
                    AppLanguage.applySelection(newValue)
                }
            }
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 700)
        .commands {
            VVTermCommands()
        }
        #endif
    }
}

// MARK: - macOS App Delegate

#if os(macOS)
struct VVTermCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.openTerminalTab) private var openTerminalTab
    @FocusedValue(\.openLocalSSHDiscovery) private var openLocalSSHDiscovery
    @FocusedValue(\.terminalSplitActions) private var terminalSplitActions

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About VVTerm") {
                AboutWindowController.shared.show()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("New Tab") {
                openTerminalTab?()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(openTerminalTab == nil)

            Button(String(localized: "Discover Local Devices...")) {
                openLocalSSHDiscovery?()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(openLocalSSHDiscovery == nil)

            Button("Close Tab") {
                terminalSplitActions?.closePane()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(terminalSplitActions == nil)
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                SettingsWindowManager.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .windowArrangement) {
            Button("Previous Tab") {
                ConnectionSessionManager.shared.selectPreviousSession()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Button("Next Tab") {
                ConnectionSessionManager.shared.selectNextSession()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
        }

        // Split commands (Pro feature)
        SplitCommands()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var lastForegroundSyncAt: Date = .distantPast
    private let foregroundSyncMinimumInterval: TimeInterval = 20

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Subscribe to CloudKit changes
        Task {
            await CloudKitManager.shared.subscribeToChanges()
        }
        NSApplication.shared.registerForRemoteNotifications()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard SyncSettings.isEnabled else { return }

        let now = Date()
        guard now.timeIntervalSince(lastForegroundSyncAt) >= foregroundSyncMinimumInterval else { return }
        lastForegroundSyncAt = now

        Task {
            await ServerManager.shared.loadData()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        Task { @MainActor in
            AppLockManager.shared.lockIfNeededForBackground()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close all connections synchronously to ensure cleanup before exit
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            ConnectionSessionManager.shared.disconnectAll()
            semaphore.signal()
        }
        // Wait up to 2 seconds for cleanup
        _ = semaphore.wait(timeout: .now() + 2)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep running in menu bar
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        guard SyncSettings.isEnabled else { return }
        Task {
            await ServerManager.shared.loadData()
        }
    }
}
#else
// MARK: - iOS App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    private var lastForegroundSyncAt: Date = .distantPast
    private let foregroundSyncMinimumInterval: TimeInterval = 20

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Subscribe to CloudKit changes
        Task {
            await CloudKitManager.shared.subscribeToChanges()
        }
        application.registerForRemoteNotifications()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard SyncSettings.isEnabled else { return }

        let now = Date()
        guard now.timeIntervalSince(lastForegroundSyncAt) >= foregroundSyncMinimumInterval else { return }
        lastForegroundSyncAt = now

        Task {
            await ServerManager.shared.loadData()
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard SyncSettings.isEnabled else {
            completionHandler(.noData)
            return
        }

        Task {
            await ServerManager.shared.loadData()
            completionHandler(.newData)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Close all connections synchronously to ensure cleanup before exit
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            ConnectionSessionManager.shared.disconnectAll()
            semaphore.signal()
        }
        // Wait up to 2 seconds for cleanup
        _ = semaphore.wait(timeout: .now() + 2)
    }

    // Handle app going to background - suspend connections to save resources
    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { @MainActor in
            ConnectionSessionManager.shared.suspendAllForBackground()
            AppLockManager.shared.lockIfNeededForBackground()
        }
    }
}

private struct InputHarnessView: View {
    @EnvironmentObject private var ghosttyApp: Ghostty.App
    @State private var lastWriteSummary = "Waiting for key input..."

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("VVTerm Input Harness")
                    .font(.headline)
                Text("Use AXe to send Ctrl+T then N")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastWriteSummary)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            InputHarnessTerminalHost { summary in
                lastWriteSummary = summary
            }
            .environmentObject(ghosttyApp)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            ghosttyApp.startIfNeeded()
        }
    }
}

private struct SSHHarnessView: View {
    @EnvironmentObject private var ghosttyApp: Ghostty.App
    @State private var session: ConnectionSession?
    @State private var statusMessage = "Preparing SSH harness..."
    @State private var didAttemptConnect = false

    private let harnessServer: Server
    private let harnessCredentials: ServerCredentials

    init() {
        let env = Foundation.ProcessInfo.processInfo.environment
        let host = env["VVTERM_SSH_HARNESS_HOST"] ?? "127.0.0.1"
        let username = env["VVTERM_SSH_HARNESS_USERNAME"] ?? "javi"
        let port = Int(env["VVTERM_SSH_HARNESS_PORT"] ?? "") ?? 22
        let name = env["VVTERM_SSH_HARNESS_NAME"] ?? "SSH Harness"

        let privateKeyData: Data? = {
            if let b64 = env["VVTERM_SSH_HARNESS_PRIVATE_KEY_BASE64"],
               let decoded = Data(base64Encoded: b64) {
                return decoded
            }
            if let key = env["VVTERM_SSH_HARNESS_PRIVATE_KEY"] {
                return key.data(using: .utf8)
            }
            return nil
        }()

        let authMethod: AuthMethod = privateKeyData == nil ? .password : .sshKey
        let serverId = UUID()
        harnessServer = Server(
            id: serverId,
            workspaceId: UUID(),
            environment: .production,
            name: name,
            host: host,
            port: port,
            username: username,
            connectionMode: .standard,
            authMethod: authMethod,
            tags: ["harness"],
            notes: "SSH harness session"
        )
        harnessCredentials = ServerCredentials(
            serverId: serverId,
            password: env["VVTERM_SSH_HARNESS_PASSWORD"],
            privateKey: privateKeyData,
            publicKey: nil,
            passphrase: env["VVTERM_SSH_HARNESS_PASSPHRASE"]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("VVTerm SSH Harness")
                    .font(.headline)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            if let session {
                SSHTerminalWrapper(
                    session: session,
                    server: harnessServer,
                    credentials: harnessCredentials,
                    isActive: true,
                    onProcessExit: {
                        statusMessage = "SSH harness process exited."
                    },
                    onReady: {
                        statusMessage = "Connected. Start zellij, then send Ctrl+T and N."
                    }
                )
                .environmentObject(ghosttyApp)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task(id: harnessServer.id) {
            await connectIfNeeded()
        }
        .onAppear {
            ghosttyApp.startIfNeeded()
        }
        .onDisappear {
            if let session {
                ConnectionSessionManager.shared.closeSession(session)
            }
        }
    }

    @MainActor
    private func connectIfNeeded() async {
        guard !didAttemptConnect else { return }
        didAttemptConnect = true

        if harnessCredentials.password == nil && harnessCredentials.privateKey == nil {
            statusMessage = "Missing SSH harness credentials. Provide password or private key env vars."
            return
        }

        statusMessage = "Opening SSH session to \(harnessServer.displayAddress)..."
        do {
            session = try await ConnectionSessionManager.shared.openConnection(to: harnessServer, forceNew: true)
            statusMessage = "SSH session started. Waiting for terminal ready..."
        } catch {
            statusMessage = "SSH harness connect failed: \(error.localizedDescription)"
        }
    }
}

private struct InputHarnessTerminalHost: UIViewRepresentable {
    @EnvironmentObject private var ghosttyApp: Ghostty.App
    let onWriteSummary: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onWriteSummary: onWriteSummary)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear
        context.coordinator.installTerminalIfNeeded(in: container, ghosttyApp: ghosttyApp)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.installTerminalIfNeeded(in: uiView, ghosttyApp: ghosttyApp)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var terminalView: GhosttyTerminalView?
        private let onWriteSummary: (String) -> Void
        private let relayQueue = DispatchQueue(label: "vvterm.input-harness.relay")
        private var relayConnection: NWConnection?
        private var relayHost = "127.0.0.1"
        private var relayPort: UInt16?
        private var softwareCtrlPrimary: String?
        private var softwareCtrlFollowup: String?
        private var didScheduleSoftwareCtrlInjection = false

        init(onWriteSummary: @escaping (String) -> Void) {
            self.onWriteSummary = onWriteSummary
            let args = Foundation.ProcessInfo.processInfo.arguments
            if let host = Self.value(after: "--vvterm-input-harness-tcp-host", in: args), !host.isEmpty {
                relayHost = host
            }
            let env = Foundation.ProcessInfo.processInfo.environment
            if let envHost = env["VVTERM_INPUT_HARNESS_TCP_HOST"], !envHost.isEmpty {
                relayHost = envHost
            }
            if let portString = Self.value(after: "--vvterm-input-harness-tcp-port", in: args),
               let port = UInt16(portString),
               port > 0 {
                relayPort = port
            }
            if let envPort = env["VVTERM_INPUT_HARNESS_TCP_PORT"],
               let port = UInt16(envPort),
               port > 0 {
                relayPort = port
            }
            if let primary = Self.value(after: "--vvterm-input-harness-software-ctrl-primary", in: args), primary.count == 1 {
                softwareCtrlPrimary = primary
            }
            if let followup = Self.value(after: "--vvterm-input-harness-software-ctrl-followup", in: args), followup.count == 1 {
                softwareCtrlFollowup = followup
            }
            if let envPrimary = env["VVTERM_INPUT_HARNESS_SOFTWARE_CTRL_PRIMARY"], envPrimary.count == 1 {
                softwareCtrlPrimary = envPrimary
            }
            if let envFollowup = env["VVTERM_INPUT_HARNESS_SOFTWARE_CTRL_FOLLOWUP"], envFollowup.count == 1 {
                softwareCtrlFollowup = envFollowup
            }
            Self.logLine("HarnessRelay init host=\(relayHost) port=\(relayPort.map(String.init) ?? "none")")
        }

        func attach(to terminalView: GhosttyTerminalView) {
            self.terminalView = terminalView
            terminalView.setupWriteCallback()
            terminalView.writeCallback = { [weak self] data in
                self?.handleTerminalWrite(data)
            }
            publish("HarnessRelay waiting for input")
            startRelayIfConfigured()
        }

        func detach() {
            relayQueue.sync {
                relayConnection?.cancel()
                relayConnection = nil
            }
            terminalView?.removeFromSuperview()
            terminalView?.writeCallback = nil
            terminalView = nil
        }

        func installTerminalIfNeeded(in container: UIView, ghosttyApp: Ghostty.App) {
            guard terminalView == nil else { return }
            ghosttyApp.startIfNeeded()
            guard let app = ghosttyApp.app else {
                publish("Preparing terminal (\(ghosttyApp.readiness.rawValue))...")
                return
            }

            let terminalView = GhosttyTerminalView(
                frame: container.bounds,
                worktreePath: NSHomeDirectory(),
                ghosttyApp: app,
                appWrapper: ghosttyApp,
                paneId: "vvterm-input-harness",
                command: nil,
                useCustomIO: true
            )
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(terminalView)
            NSLayoutConstraint.activate([
                terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                terminalView.topAnchor.constraint(equalTo: container.topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            attach(to: terminalView)
            scheduleSoftwareCtrlInjectionIfNeeded()
        }

        private func handleTerminalWrite(_ data: Data) {
            let line = Self.renderWriteLine(data)
            Self.logLine(line)
            publish(line)
            relayQueue.async { [weak self] in
                guard let self = self else { return }
                guard let relayConnection = self.relayConnection else { return }
                relayConnection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        Self.logLine("HarnessRelay send error: \(error.localizedDescription)")
                    }
                })
            }
        }

        private func startRelayIfConfigured() {
            guard let relayPort else {
                publish("HarnessRelay local trace mode")
                return
            }
            guard let nwPort = NWEndpoint.Port(rawValue: relayPort) else {
                publish("HarnessRelay invalid tcp port \(relayPort)")
                return
            }

            let connection = NWConnection(host: NWEndpoint.Host(relayHost), port: nwPort, using: .tcp)
            relayConnection = connection
            publish("HarnessRelay connecting to \(relayHost):\(relayPort)")

            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    Self.logLine("HarnessRelay connected")
                    self.publish("HarnessRelay connected")
                    self.receiveLoop()
                case .waiting(let error):
                    Self.logLine("HarnessRelay waiting: \(error.localizedDescription)")
                    self.publish("HarnessRelay waiting")
                case .failed(let error):
                    Self.logLine("HarnessRelay failed: \(error.localizedDescription)")
                    self.publish("HarnessRelay failed")
                case .cancelled:
                    Self.logLine("HarnessRelay cancelled")
                default:
                    break
                }
            }

            connection.start(queue: relayQueue)
        }

        private func receiveLoop() {
            guard let relayConnection else { return }
            relayConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self else { return }
                if let data, !data.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.terminalView?.feedData(data)
                    }
                }
                if isComplete {
                    Self.logLine("HarnessRelay peer closed")
                    self.publish("HarnessRelay peer closed")
                    return
                }
                if let error {
                    Self.logLine("HarnessRelay receive error: \(error.localizedDescription)")
                    self.publish("HarnessRelay receive error")
                    return
                }
                self.receiveLoop()
            }
        }

        private func scheduleSoftwareCtrlInjectionIfNeeded() {
            guard !didScheduleSoftwareCtrlInjection else { return }
            guard let primary = softwareCtrlPrimary, let followup = softwareCtrlFollowup else { return }
            didScheduleSoftwareCtrlInjection = true
            publish("HarnessRelay injecting software ctrl sequence primary='\(primary)' followup='\(followup)'")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.terminalView?.harnessInjectSoftwareCtrlSequence(primary: primary, followup: followup)
            }
        }

        private func publish(_ line: String) {
            DispatchQueue.main.async { [onWriteSummary] in
                onWriteSummary(line)
            }
        }

        private static func value(after flag: String, in args: [String]) -> String? {
            guard let flagIndex = args.firstIndex(of: flag) else { return nil }
            let valueIndex = flagIndex + 1
            guard valueIndex < args.count else { return nil }
            return args[valueIndex]
        }

        private static func renderWriteLine(_ data: Data) -> String {
            let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            let text = String(decoding: data, as: UTF8.self)
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "HarnessWrite bytes=\(hex) text='\(text)'"
        }

        private static func logLine(_ line: String) {
            if let payload = "\(line)\n".data(using: .utf8) {
                FileHandle.standardError.write(payload)
            }
        }
    }
}
#endif
