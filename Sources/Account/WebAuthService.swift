// SPDX-License-Identifier: Apache-2.0
import AuthenticationServices
import UIKit

enum WebAuthError: Error { case cancelled, cannotStart }

/// Thin wrapper around `ASWebAuthenticationSession` — the system auth sheet used
/// for GitHub sign-in. Presents the OAuth URL, returns the final `halo://`
/// callback URL the app then parses for the session token.
@MainActor
final class WebAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        if let key = windows.first(where: { $0.isKeyWindow }) { return key }
        if let any = windows.first { return any }
        if let scene = scenes.first { return UIWindow(windowScene: scene) }
        // A foreground app always has a window scene; this is unreachable.
        preconditionFailure("WebAuthService: no UIWindowScene to present from")
    }

    /// Open `url` and resolve with the callback URL on the `scheme`.
    func authenticate(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? WebAuthError.cancelled)
                }
            }
            session.presentationContextProvider = self
            // Keep the user's existing web session so they don't re-type GitHub
            // creds every time; flip to true if we want a clean sheet each time.
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: WebAuthError.cannotStart)
            }
        }
    }
}
