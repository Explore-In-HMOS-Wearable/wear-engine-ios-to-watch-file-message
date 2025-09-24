import UIKit
import SwiftUI
import WearEngineSDK

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private enum Notice {
        static let openURL = Notification.Name("openURLContextsNotification")
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = makeWindow(for: windowScene, root: WearEngineView())
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        runBackgroundTask(for: 25)
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url else { return }
        HiWear.getAuthClient().processAuthResult(with: url)
        NotificationCenter.default.post(name: Notice.openURL, object: url.absoluteString)
    }
}

// MARK: - Helpers

private extension SceneDelegate {
    func makeWindow<Root: View>(for scene: UIWindowScene, root: Root) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: root)
        return window
    }

    func runBackgroundTask(for seconds: TimeInterval) {
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask { }
        let deadline = DispatchTime.now() + seconds
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
