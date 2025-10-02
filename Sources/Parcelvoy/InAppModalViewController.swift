import UIKit
import WebKit

public enum InAppAction: String, CaseIterable {
    case dismiss, custom
}

protocol InAppModelViewControllerDelegate: AnyObject {
    var useDarkMode: Bool { get }
    func handle(action: InAppAction, context: [String: Any], notification: ParcelvoyNotification)
    func onError(error: Error)
}

class InAppModalViewController: UIViewController {

    weak var delegate: InAppModelViewControllerDelegate?

    private let webView = WKWebView()
    private let contentController = WKUserContentController()
    private var notification: ParcelvoyNotification!
    private var onLoad: ((UIViewController) -> Void)?

    private let transitionDelegate = OverlayTransitioningDelegate()
    private var initialLoadNavigation: WKNavigation?

    init(
        notification: ParcelvoyNotification,
        delegate: InAppModelViewControllerDelegate,
        onLoad: @escaping (UIViewController) -> Void
    ) {
        self.notification = notification
        self.delegate = delegate
        self.onLoad = onLoad

        super.init(nibName: nil, bundle: nil)

        transitioningDelegate = transitionDelegate
        modalPresentationStyle = .custom

        view.backgroundColor = .clear

        view.addSubview(webView)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.configuration.preferences.javaScriptEnabled = true
        webView.navigationDelegate = self

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.pinToEdges(parentView: view)

        InAppAction.allCases.forEach {
            webView.configuration.userContentController.add(self, name: $0.rawValue)
        }

        let closeScript = "window.dismiss = function() { window.webkit.messageHandlers.dismiss.postMessage(''); }"
        let closeUserScript = WKUserScript(source: closeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(closeUserScript)

        let customSource = "window.trigger = function(obj) { window.webkit.messageHandlers.custom.postMessage(obj); }"
        let customUserScript = WKUserScript(source: customSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(customUserScript)

        if let notification = notification.content as? HtmlNotification {
            initialLoadNavigation = webView.loadHTMLString(notification.html, baseURL: nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func processAction(action: InAppAction, body: [String: Any] = [:]) {
        delegate?.handle(action: action, context: body, notification: notification)
    }
}

extension InAppModalViewController: WKNavigationDelegate, WKScriptMessageHandler {
    private static var addDarkMode: String = "document.documentElement.classList.add('darkMode');"
    private static var removeDarkMode: String = "document.documentElement.classList.remove('darkMode');"

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.onError(error: error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation, navigation === initialLoadNavigation else { return }
        if delegate?.useDarkMode == true {
            webView.evaluateJavaScript(Self.addDarkMode)
        } else {
            webView.evaluateJavaScript(Self.removeDarkMode)
        }
        if let onLoad {
            onLoad(self)
            self.onLoad = nil
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }

        // If matches local HTML loading, allow
        if url.absoluteString == "about:blank" {
            return decisionHandler(.allow)
        }

        // If matches `parcelvoy` deeplink path
        if url.absoluteString.starts(with: "parcelvoy://") {
            decisionHandler(.cancel)

            if url.absoluteString == "parcelvoy://dismiss" {
                return processAction(action: .dismiss)
            }

            return processAction(action: .custom, body: [
                "url": url.absoluteString
            ])
        }

        // Disable all other page actions, pop open in a new browser
        decisionHandler(.cancel)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let action = InAppAction(rawValue: message.name) else { return }
        processAction(action: action, body: message.body as? [String: Any] ?? [:])
    }
}


private class OverlayTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        OverlayPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

private class OverlayPresentationController: UIPresentationController {

    private let dimmedBackgroundView = UIView()
    private let alpha: CGFloat = 0.5

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        containerView.addSubview(self.dimmedBackgroundView)
        dimmedBackgroundView.backgroundColor = .black
        dimmedBackgroundView.frame = containerView.bounds
        dimmedBackgroundView.alpha = 0

        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmedBackgroundView.alpha = self.alpha
            }, completion: nil)
        } else {
            dimmedBackgroundView.alpha = alpha
        }
    }

    override func dismissalTransitionWillBegin() {
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmedBackgroundView.alpha = 0
            }, completion: nil)
        } else {
            dimmedBackgroundView.alpha = 0
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate { _ in
            self.dimmedBackgroundView.frame = .init(origin: .zero, size: size)
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        dimmedBackgroundView.removeFromSuperview()
    }
}
