import SwiftUI

struct DonationView: View {
    @State private var selectedMethod: DonationMethod = .wechat

    enum DonationMethod: String, CaseIterable, Identifiable {
        case wechat = "wechat"
        case alipay = "alipay"
        case paypal = "paypal"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wechat: return "微信"
            case .alipay: return "支付宝"
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

            Text("喜欢就请我喝杯咖啡，完全随意☕️")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    Text("即将支持")
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
                    Text("即将支持")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
