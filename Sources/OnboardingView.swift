import SwiftUI

/// 首次启动（或清空地址后）显示的引导页。
struct OnboardingView: View {
    @EnvironmentObject private var store: ServerStore
    @Binding var showSettings: Bool

    @State private var text: String = ""
    @State private var hint: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arcaea 面板")
                        .font(.largeTitle.bold())
                    Text("把你自建的 Arcaea-server 网页端，装进一个原生 App 里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("服务端地址")
                        .font(.headline)
                    TextField("例如 192.168.1.10:3003 或 https://arc.example.com", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit(commit)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if let hint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(action: commit) {
                        Text("保存并连接")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("填之前先确认")
                        .font(.headline)
                    bullet("服务端已启动：`python launch.py` 或 gunicorn，默认监听 3003 端口。")
                    bullet("iPad 与电脑在同一个局域网；用电脑的局域网 IP，别用 127.0.0.1。")
                    bullet("本机 http 用「http://」，nginx 加证书的用「https://」；自签名证书到「设置」里信任。")
                    bullet("想从公网连：先把路由器端口映射或反代配好，再用域名。")
                }
                .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { text = store.baseURLString }
    }

    private func commit() {
        guard let url = ServerStore.normalize(text) else {
            hint = "地址看着不对：至少要有主机名或 IP，例如 192.168.1.10:3003"
            return
        }
        hint = nil
        store.save(url.absoluteString)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").font(.body.weight(.bold)).foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
