import Foundation
import WebKit

/// 用一个轻量包装持有 WKWebView，避免 SwiftUI 视图里出现强引用环。
final class WKWebViewBox {
    let raw: WKWebView
    init(_ webView: WKWebView) { self.raw = webView }
}
