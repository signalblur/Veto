import SwiftUI
import VetoCore

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            StatusView()
                .tabItem {
                    Label("Status", systemImage: "shield")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .fullScreenCover(isPresented: .init(
            get: { !model.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingFlow()
        }
    }
}
