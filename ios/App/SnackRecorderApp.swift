import SwiftUI
import LocalAuthentication

@main
struct SnackRecorderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = AuthenticationSession()
    @StateObject private var model = SnackViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if session.unlocked {
                    SnackListView(model: model)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(SnackTheme.orange)
                        Text("Snack Recorder is locked").font(.title2.bold())
                        Text(session.message ?? "Use Face ID, Touch ID, or your device passcode to unlock your snack records.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Unlock") { session.unlock() }
                            .buttonStyle(.borderedProminent).disabled(session.authenticating)
                            .accessibilityIdentifier("unlock")
                    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(SnackTheme.background)
                }
            }
            .tint(SnackTheme.orange)
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        SnackTheme.background.ignoresSafeArea()
                        Label("Snack Recorder", systemImage: "lock.fill").font(.title2.bold())
                    }.accessibilityIdentifier("privacy-cover")
                }
            }
            .task { if !LaunchSettings.uiTesting { session.unlock() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { session.lock() }
                if phase == .active && !LaunchSettings.uiTesting { session.unlock() }
            }
        }
    }
}

@MainActor
final class AuthenticationSession: ObservableObject {
    @Published private(set) var unlocked = false
    @Published private(set) var authenticating = false
    @Published private(set) var message: String?
    private var context: LAContext?
    private var generation = 0

    func lock() {
        generation += 1
        context?.invalidate()
        context = nil
        authenticating = false
        unlocked = false
    }

    func unlock() {
        guard !unlocked, !authenticating else { return }
        #if DEBUG
        // Only the UI-test runner injects authentication. Release builds cannot use this path.
        if LaunchSettings.uiTesting {
            unlocked = !ProcessInfo.processInfo.arguments.contains("--authentication-fails")
            message = unlocked ? nil : "Authentication was cancelled. Your records remain locked."
            return
        }
        #endif
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = "Set up a device passcode or biometrics in Settings to unlock your records."
            return
        }
        self.context = context
        authenticating = true
        let requestGeneration = generation
        Task { @MainActor in
            defer {
                if requestGeneration == generation { authenticating = false; self.context = nil }
            }
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "View your snack records")
                guard requestGeneration == generation else { return }
                unlocked = success
                message = nil
            } catch {
                if requestGeneration == generation { message = error.localizedDescription }
            }
        }
    }
}

@MainActor
enum LaunchSettings {
    static var uiTesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
    static var today: Date { uiTesting ? SnackDates.date(for: "2026-10-31")! : Date() }
}

enum SnackTheme {
    static let orange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let lightOrange = Color.orange.opacity(0.13)
}
