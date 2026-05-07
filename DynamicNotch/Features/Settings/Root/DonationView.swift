import SwiftUI

struct DonationView: View {
    @State private var selectedMethod: DonationMethod = .wechat

    enum DonationMethod: String, CaseIterable, Identifiable {
        case wechat = "wechat"
        case alipay = "alipay"
        case paypal = "paypal"
        case visa   = "visa"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wechat: return "微信"
            case .alipay: return "支付宝"
            case .paypal: return "PayPal"
            case .visa:   return "Visa / Card"
            }
        }

        var badge: String {
            switch self {
            case .wechat: return "微"
            case .alipay: return "支"
            case .paypal: return "P"
            case .visa:   return "V"
            }
        }

        var accentColor: Color {
            switch self {
            case .wechat: return Color(red: 0.15, green: 0.77, blue: 0.28)
            case .alipay: return Color(red: 0.07, green: 0.44, blue: 0.87)
            case .paypal: return Color(red: 0.0,  green: 0.30, blue: 0.67)
            case .visa:   return Color(red: 0.10, green: 0.18, blue: 0.54)
            }
        }

        var available: Bool {
            self == .wechat
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 320)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(.pink)
            Text("支持 OpenNotch")
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var content: some View {
        VStack(spacing: 16) {
            methodPicker
            qrArea
            tagline
        }
        .padding(20)
    }

    private var methodPicker: some View {
        HStack(spacing: 8) {
            ForEach(DonationMethod.allCases) { method in
                Button {
                    selectedMethod = method
                } label: {
                    VStack(spacing: 4) {
                        methodIcon(method)
                            .frame(width: 32, height: 32)
                            .background(
                                selectedMethod == method
                                    ? method.accentColor.opacity(0.15)
                                    : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        Text(method.label)
                            .font(.system(size: 10))
                            .foregroundStyle(selectedMethod == method ? method.accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .opacity(method.available ? 1 : 0.4)
                .disabled(!method.available)
            }
        }
    }

    private func methodIcon(_ method: DonationMethod) -> some View {
        Text(method.badge)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(selectedMethod == method ? method.accentColor : .secondary)
    }

    @ViewBuilder
    private var qrArea: some View {
        switch selectedMethod {
        case .wechat:
            VStack(spacing: 8) {
                Image("wechat_qr")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                Text("微信扫码赞赏")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        default:
            VStack(spacing: 10) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("即将支持")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 160, height: 160)
        }
    }

    private var tagline: some View {
        Text("喜欢就请我喝杯咖啡，完全随意 ☕")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}
