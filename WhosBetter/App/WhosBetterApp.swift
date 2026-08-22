import SwiftUI

@main
struct WhosBetterApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 900, idealWidth: 1240, minHeight: 600, idealHeight: 1000)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 1000)
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
