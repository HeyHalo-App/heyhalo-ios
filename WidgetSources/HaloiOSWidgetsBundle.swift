// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import WidgetKit

/// The widget extension's entry point. Only the Reach Live Activity for now
/// (the iOS "notch" surface — ADR 0037 §16); home-screen widgets can join later.
@main
struct HaloiOSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReachLiveActivityWidget()
    }
}
