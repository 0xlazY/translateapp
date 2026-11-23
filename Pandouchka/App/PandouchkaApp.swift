import SwiftData
import SwiftUI

@main
struct PandouchkaApp: App {
    let container = Persistence.container()

    init() {
        UserDefaults.standard.register(defaults: [
            Prefs.directions: "both",
            Prefs.newPerDay: 10,
            Prefs.retention: 0.9,
            Prefs.autoPlay: true,
            Prefs.showStress: true,
            Prefs.speechRate: 0.42,
            Prefs.readerSize: 22.0,
            Prefs.showLineTranslation: false,
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
