import SwiftUI
import WebKit

struct SettingsSheet: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var resultIsError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.10:3003", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(save)

                    HStack {
                        Button(testing ? "测试中…" : "测试连接") { test() }
                            .disabled(testing)
                        Spacer()
                        if let testResult {
                            Text(testResult)
                                .font(.footnote)
                                .foregroundStyle(resultIsError ? .red : .secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Button("保存并返回") { saveAndDismiss() }
                } header: {
                    Text("服务端地址")
                } footer: {
                    Text("不带 http:// 时默认按 http 处理。改完记得保存。")
                }

                Section {
                    Toggle("信任自签名 / 不受信任的 HTTPS 证书", isOn: $store.allowInsecureTLS)
                } header: {
                    Text("安全")
                } footer: {
                    Text("只在你自己的私服上用。开着它，App 会接受任何 HTTPS 证书（包括自签名的），关掉则严格校验。")
                }

                Section("数据") {
                    Button("清除 Cookie 与网页缓存") { clearWebData() }
                    Button("重置地址，回到引导页", role: .destructive) {
                        store.reset()
                        dismiss()
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: Self.versionString)
                    LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "-")
                    LabeledContent("运行环境", value: "iOS \(UIDevice.current.systemVersion)")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { text = store.baseURLString }
        }
    }

    private static var versionString: String {
        let dict = Bundle.main.infoDictionary
        let short = dict?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func save() {
        store.save(text)
        if ServerStore.normalize(text) == nil {
            testResult = "地址格式不对"
            resultIsError = true
        }
    }

    private func saveAndDismiss() {
        save()
        dismiss()
    }

    private func test() {
        guard let url = ServerStore.normalize(text) else {
            testResult = "地址格式不对"
            resultIsError = true
            return
        }
        testing = true
        testResult = nil
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let started = Date()

        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                testing = false
                if let http = response as? HTTPURLResponse {
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    testResult = "HTTP \(http.statusCode) · \(ms) ms"
                    resultIsError = http.statusCode >= 400
                } else {
                    testResult = "连不上：\(error?.localizedDescription ?? "未知错误")"
                    resultIsError = true
                }
            }
        }.resume()
    }

    private func clearWebData() {
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
            DispatchQueue.main.async {
                testResult = "已清除网页数据"
                resultIsError = false
            }
        }
    }
}
