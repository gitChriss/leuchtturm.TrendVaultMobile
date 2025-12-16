//
//  FlowLayout.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI

struct FlowLayout: Layout {

    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {

        let width = proposal.width ?? 0
        if width <= 0 {
            let fallback = subviews.reduce(CGSize(width: 0, height: 0)) { partial, sub in
                let s = sub.sizeThatFits(.unspecified)
                return CGSize(width: max(partial.width, s.width), height: partial.height + s.height + spacing)
            }
            return fallback
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)

            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)

            if x + size.width > bounds.width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            sub.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
