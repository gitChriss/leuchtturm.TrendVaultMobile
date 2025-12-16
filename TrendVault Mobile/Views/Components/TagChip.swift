//
//  TagChip.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI

struct TagChip: View {

    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
            )
    }
}
