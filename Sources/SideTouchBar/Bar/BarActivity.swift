import Combine

/// Whether the bar is out, so background polling (menus, text focus, AI
/// context) can pause while it's hidden.
@MainActor
final class BarActivity: ObservableObject {
    static let shared = BarActivity()

    @Published var isExpanded = false
}
