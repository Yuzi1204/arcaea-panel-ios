import Foundation
import SwiftUI
import WebKit

/// 私服地址与偏好设置（持久化到 UserDefaults）。
final class ServerStore: ObservableObject {
    private enum Key {
        static let url = "panel.server.url"
        static let insecure = "panel.allow.insecure.tls"
    }

    private let defaults = UserDefaults.standard

    @Published var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Key.url) }
    }

    /// 允许自签名 / 不受信任的 HTTPS 证书（本地自建服务常用）。
    @Published var allowInsecureTLS: Bool {
        didSet { defaults.set(allowInsecureTLS, forKey: Key.insecure) }
    }

    init() {
        self.baseURLString = defaults.string(forKey: Key.url) ?? ""
        self.allowInsecureTLS = defaults.object(forKey: Key.insecure) as? Bool ?? true
    }

    /// 规范化为可用的 URL（补全 scheme、去掉尾部斜杠）。
    var resolvedURL: URL? { ServerStore.normalize(baseURLString) }

    static func normalize(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    func save(_ raw: String) {
        baseURLString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        baseURLString = ""
        defaults.removeObject(forKey: Key.url)
    }
}

/// WKWebView 的导航状态（供 SwiftUI 工具栏绑定）。
final class WebState: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var pageTitle: String = ""
    @Published var errorText: String?

    var webView: WKWebViewBox?

    func goBack() { webView?.raw.goBack() }
    func goForward() { webView?.raw.goForward() }
    func reload() {
        errorText = nil
        webView?.raw.reload()
    }
    func load(_ url: URL) {
        errorText = nil
        webView?.raw.load(URLRequest(url: url))
    }
}
