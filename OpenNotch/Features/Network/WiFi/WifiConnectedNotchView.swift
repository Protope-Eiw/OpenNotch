//
//  WifiConnectedNotchView.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct WifiConnectedNotchView: View {
    @Environment(\.notchScale) var scale
    @ObservedObject var networkViewModel: NetworkViewModel

    private var displayName: String {
        let name = networkViewModel.wifiName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Wi-Fi" : name
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "wifi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.gradient)
                    .contentTransition(.symbolEffect(.replace))
            }
            
            Spacer()
            
            Text(verbatim: displayName)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
