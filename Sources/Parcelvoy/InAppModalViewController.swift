import UIKit
import WebKit

public enum InAppAction: String, CaseIterable {
    case close, custom
}

class InAppModalViewController: UIViewController {

    let webView = WKWebView()
    let contentController = WKUserContentController()
    var notification: ParcelvoyNotification!
    weak var delegate: InAppDelegate?

    init(notification: ParcelvoyNotification, delegate: InAppDelegate) {
        self.notification = notification
        self.delegate = delegate

        super.init(nibName: nil, bundle: nil)
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

        let closeScript = "window.close = function() { window.webkit.messageHandlers.close.postMessage(''); }"
        let closeUserScript = WKUserScript(source: closeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(closeUserScript)

        let customSource = "window.trigger = function(obj) { window.webkit.messageHandlers.custom.postMessage(obj); }"
        let customUserScript = WKUserScript(source: customSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(customUserScript)

        if let notification = notification.content as? HtmlNotification {
            self.webView.loadHTMLString(notification.html, baseURL: nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension InAppModalViewController: WKNavigationDelegate, WKScriptMessageHandler {

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error)

        // TODO: On error what happens? Can an error even happen?
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let action = InAppAction(rawValue: message.name) else { return }
        let body = message.body as? [String: AnyObject] ?? [:]
        self.delegate?.handle(action: action, context: body, notification: notification)
    }
}
