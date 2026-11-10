import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ServerStore
    @StateObject private var web = WebState()
    @State private var showSettings = false

    var body: some View {
        Group {
            if let url = store.resolvedURL {
                NavigationStack {
                    panel(baseURL: url)
                }
                .id(store.baseURLString)
            } else {
                OnboardingView(showSettings: $showSettings)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(store)
        }
    }

    // MARK: - 主面板

    private func panel(baseURL: URL) -> some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            WebPanelView(url: baseURL, allowInsecureTLS: store.allowInsecureTLS, state: web)

            if web.isLoading {
                ProgressView(value: min(max(web.progress, 0.03), 1.0))
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }

            if let error = web.errorText {
                ErrorBanner(text: error) {
                    web.load(baseURL)
                }
                .padding(12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: web.errorText)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .navigationTitle(web.pageTitle.isEmpty ? (baseURL.host ?? "Arcaea 面板") : web.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIApplication.shared.open(baseURL)
                } label: {
                    Image(systemName: "safari")
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            barButton("chevron.backward", enabled: web.canGoBack) { web.goBack() }
            Spacer()
            barButton("chevron.forward", enabled: web.canGoForward) { web.goForward() }
            Spacer()
            barButton("house", enabled: true) {
                if let url = store.resolvedURL { web.load(url) }
            }
            Spacer()
            barButton(web.isLoading ? "xmark" : "arrow.clockwise", enabled: true) {
                if web.isLoading { web.webView?.raw.stopLoading() } else { web.reload() }
            }
            Spacer()
            barButton("gearshape", enabled: true) { showSettings = true }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func barButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}

struct ErrorBanner: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Button("重试", action: retry)
                    .font(.footnote.bold())
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.orange.opacity(0.35))
        )
    }
}
