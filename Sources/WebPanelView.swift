import SwiftUI
import WebKit

/// 把私服网页端包进 WKWebView：保留 Cookie、支持下拉刷新、JS 弹窗、前进后退手势。
struct WebPanelView: UIViewRepresentable {
    let url: URL
    let allowInsecureTLS: Bool
    let state: WebState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, allowInsecureTLS: allowInsecureTLS)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = "ArcaeaPanel/1.0"

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.attach(to: webView)
        state.webView = WKWebViewBox(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.allowInsecureTLS = allowInsecureTLS
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var allowInsecureTLS: Bool
        private let state: WebState
        private var observations: [NSKeyValueObservation] = []

        init(state: WebState, allowInsecureTLS: Bool) {
            self.state = state
            self.allowInsecureTLS = allowInsecureTLS
        }

        func attach(to webView: WKWebView) {
            observations = [
                webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                    self?.publish { $0.canGoBack = view.canGoBack }
                },
                webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                    self?.publish { $0.canGoForward = view.canGoForward }
                },
                webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                    self?.publish { $0.progress = view.estimatedProgress }
                },
                webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                    self?.publish { $0.isLoading = view.isLoading }
                },
                webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                    self?.publish { $0.pageTitle = view.title ?? "" }
                },
            ]
        }

        func detach() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
        }

        private func publish(_ block: @escaping (WebState) -> Void) {
            let state = self.state
            if Thread.isMainThread {
                block(state)
            } else {
                DispatchQueue.main.async { block(state) }
            }
        }

        @objc func handleRefresh(_ control: UIRefreshControl) {
            state.webView?.raw.reload()
            // 兜底：网络卡死时别让刷新圈一直转
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                control.endRefreshing()
            }
        }

        // MARK: 导航回调

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.errorText = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            let host = state.webView?.raw.url?.host ?? "服务端"
            let message: String
            switch nsError.code {
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorNetworkConnectionLost:
                message = "连不上 \(host)：检查服务端是否已启动、iPad 与电脑是否同一 Wi-Fi。"
            case NSURLErrorTimedOut:
                message = "连接 \(host) 超时。"
            case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorSecureConnectionFailed:
                message = "HTTPS 证书被拒绝：在「设置」里打开「信任自签名证书」，或改用 http。"
            default:
                message = "加载失败（\(nsError.code)）：\(nsError.localizedDescription)"
            }
            state.errorText = message
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
            if scheme == "tel" || scheme == "mailto" || scheme == "sms" {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        /// target="_blank" 的链接一律在当前视图打开，避免点了没反应。
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let target = navigationAction.request.url {
                webView.load(URLRequest(url: target))
            }
            return nil
        }

        /// 自签名 HTTPS：仅在用户显式允许时放行。
        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if allowInsecureTLS,
               challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }

        // MARK: JS 弹窗（WKWebView 默认不显示，必须自己实现）

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
            present(alert, fallback: completionHandler)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
            present(alert, fallback: { completionHandler(false) })
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: webView.title, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            present(alert, fallback: { completionHandler(nil) })
        }

        private func present(_ alert: UIAlertController, fallback: @escaping () -> Void) {
            guard let host = Self.topViewController else {
                fallback()
                return
            }
            host.present(alert, animated: true)
        }

        private static var topViewController: UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            var top = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }
    }
}
