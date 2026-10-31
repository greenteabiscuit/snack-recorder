import SwiftUI
import LocalAuthentication

@main
struct SnackRecorderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var authenticationContext: LAContext?
    @State private var message: String?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if unlocked {
                    SnackListView()
                } else {
                    ContentUnavailableView {
                        Label("Snack Recorder", systemImage: "lock.fill")
                    } description: {
                        Text(message ?? "Unlock to see your snack records.")
                    } actions: {
                        Button("Unlock", action: unlock).buttonStyle(.borderedProminent)
                            .disabled(authenticating)
                    }
                }
            }
            .task { unlock() }
            .onChange(of: scenePhase) { _, phase in
                // Do not lock on inactive: authentication itself makes the app inactive.
                if phase == .background {
                    unlocked = false
                    authenticationContext?.invalidate()
                }
            }
        }
    }

    private func unlock() {
        guard !unlocked, !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = "Set up a device passcode or biometrics in Settings to unlock your records."
            return
        }
        authenticating = true
        authenticationContext = context
        Task { @MainActor in
            defer {
                authenticating = false
                authenticationContext = nil
            }
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "View your snack records")
                unlocked = success && scenePhase != .background
                message = nil
            } catch { message = error.localizedDescription }
        }
    }
}
