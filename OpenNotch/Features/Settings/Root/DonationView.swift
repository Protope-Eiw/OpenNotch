import SwiftUI

struct DonationView: View {
    @State private var selectedMethod: DonationMethod = .wechat
    @State private var showingFeedback = false

    enum DonationMethod: String, CaseIterable, Identifiable {
        case wechat = "wechat"
        case alipay = "alipay"
        case paypal = "paypal"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wechat: return L10n.app("donation.method.wechat", fallback: "WeChat")
            case .alipay: return L10n.app("donation.method.alipay", fallback: "Alipay")
            case .paypal: return "PayPal"
            }
        }

        var accentColor: Color {
            switch self {
            case .wechat: return Color(red: 0.15, green: 0.77, blue: 0.28)
            case .alipay: return Color(red: 0.07, green: 0.44, blue: 0.87)
            case .paypal: return Color(red: 0.0,  green: 0.30, blue: 0.67)
            }
        }

        var available: Bool { self == .wechat }
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(DonationMethod.allCases) { method in
                    methodButton(method)
                }
            }

            qrPanel

            Text(L10n.app("donation.buyCoffee", fallback: "Buy me a coffee, totally optional ☕️"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button {
                showingFeedback = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 12))
                    Text(L10n.app("donation.sendFeedback", fallback: "Send feedback or suggestions"))
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingFeedback) {
            FeedbackSheet()
        }
    }

    private func methodButton(_ method: DonationMethod) -> some View {
        Button {
            guard method.available else { return }
            selectedMethod = method
        } label: {
            HStack(spacing: 6) {
                Text(method.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedMethod == method ? method.accentColor : (method.available ? .primary : .secondary))

                if !method.available {
                    Text(L10n.app("donation.comingSoon", fallback: "Coming soon"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                selectedMethod == method && method.available
                    ? method.accentColor.opacity(0.1)
                    : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedMethod == method && method.available
                            ? method.accentColor.opacity(0.4)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!method.available)
        .opacity(method.available ? 1 : 0.5)
    }

    @ViewBuilder
    private var qrPanel: some View {
        switch selectedMethod {
        case .wechat:
            Image("wechat_qr")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

        default:
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 220, height: 220)
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.app("donation.comingSoon", fallback: "Coming soon"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Feedback Sheet

private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var contactInfo = ""
    @State private var state: SubmitState = .idle

    enum SubmitState { case idle, sending, success, failure }

    private let maxLength = 1000

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(L10n.app("feedback.title", fallback: "Feedback & Suggestions"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(L10n.app("feedback.close", fallback: "Close")) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Message
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.app("feedback.yourFeedback", fallback: "Your Feedback"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $message)
                                .font(.system(size: 13))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .onChange(of: message) { _, v in
                                    if v.count > maxLength { message = String(v.prefix(maxLength)) }
                                }
                            if message.isEmpty {
                                Text(L10n.app("feedback.placeholder", fallback: "Anything to share? Feature suggestions, issues, all welcome…"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .allowsHitTesting(false)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                        HStack {
                            Spacer()
                            Text("\(message.count) / \(maxLength)")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Contact (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.app("feedback.contact", fallback: "Contact Info (optional)"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField(L10n.app("feedback.contactPlaceholder", fallback: "Email or WeChat for reply"), text: $contactInfo)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Submit button
                    HStack {
                        Spacer()
                        switch state {
                        case .idle:
                            Button(L10n.app("feedback.send", fallback: "Send")) { submit() }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        case .sending:
                            ProgressView().controlSize(.small)
                        case .success:
                            Label(L10n.app("feedback.sent", fallback: "Sent, thank you!"), systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                        case .failure:
                            Label(L10n.app("feedback.failed", fallback: "Send failed, please try again later"), systemImage: "exclamationmark.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 360)
    }

    private func submit() {
        guard state == .idle else { return }
        state = .sending

        var body: [String: String] = [
            "access_key": "bf1500a5-f080-4407-b40d-3d949dd5272f",
            "subject":    "OpenNotch User Feedback",
            "message":    message
        ]
        if !contactInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["from_name"] = contactInfo
        }

        guard let url = URL(string: "https://api.web3forms.com/submit"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            state = .failure
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        URLSession.shared.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode
                state = (code == 200) ? .success : .failure
                if state == .success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
                }
            }
        }.resume()
    }
}
