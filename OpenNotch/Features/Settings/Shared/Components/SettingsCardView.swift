//
//  SettingsCardView.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String?
    
    private let content: Content
    
    init(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            
        } label: {
            if let title {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                }
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .groupBoxStyle(SettingsCardGroupBoxStyle())
    }
}

private struct SettingsCardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .padding(.leading, 15)
            configuration.content
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .circular)
                        .fill(.quinary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .circular)
                                .strokeBorder(.quaternary)
                        )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
