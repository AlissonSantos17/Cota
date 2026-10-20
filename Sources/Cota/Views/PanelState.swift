import SwiftUI

/// Panel state that something outside the panel has to reach: Add pair opens
/// the new pair's row so the person lands on it the next time the panel opens.
@MainActor
final class PanelState: ObservableObject {
    static let shared = PanelState()

    /// One row open at a time; clicking another moves the detail there.
    @Published var expandedPairID: String?
}
