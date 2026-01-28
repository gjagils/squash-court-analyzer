import SwiftUI
import SwiftData

@main
struct SquashAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SavedMatch.self, SavedGame.self, SavedPoint.self])
    }
}
