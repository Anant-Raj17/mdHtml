import SwiftUI

@main
struct MdHtmlApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
