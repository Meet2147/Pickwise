import SwiftUI

@main
struct WhosBetterApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Comparison") { store.newComparison() }.keyboardShortcut("n")
            }
        }
        Settings {
            SettingsView().environmentObject(store)
        }
    }
}
