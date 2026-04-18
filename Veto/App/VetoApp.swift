import SwiftUI

@main
struct VetoApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .task {
                    await model.bootstrap()
                }
        }
    }
}
