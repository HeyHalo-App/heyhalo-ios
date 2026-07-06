// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import UIKit

/// Re-enables iOS's interactive edge-swipe-to-go-back on a screen that hides the
/// system back button (we use a custom branded header in `ChatView`, and hiding
/// the system back button otherwise disables the pop gesture). Drop it in a
/// `.background(EnableSwipeBack())`.
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Proxy() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// A tiny hosted controller that, once in the hierarchy, hands the nav
    /// controller's interactive-pop recognizer a delegate which only allows the
    /// swipe when there's something to pop (so it's a no-op at the root).
    private final class Proxy: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            navigationController?.interactivePopGestureRecognizer?.delegate = self
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
