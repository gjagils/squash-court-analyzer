import SwiftUI
import WidgetKit

/// The widget extension of the app: only the Live Activities of a live match
/// and of a team match (lock screen and Dynamic Island), no home screen widgets.
@main
struct SquashLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        LiveScoreActivityWidget()
        TeamScoreActivityWidget()
    }
}
