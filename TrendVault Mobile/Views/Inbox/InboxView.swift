//
//  InboxView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import SwiftUI
import Observation
import UIKit

struct InboxView: View {

    @Bindable var store: LocalStore

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.items) { item in
                            InboxTile(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No items yet",
            systemImage: "square.grid.2x2",
            description: Text("Import screenshots via the plus button.")
        )
        .padding(.horizontal, 24)
    }
}

private struct InboxTile: View {

    let item: TrendItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            GeometryReader { proxy in
                let side = proxy.size.width

                ThumbnailView(filename: item.imageFilename)
                    .frame(width: side, height: side)
                    .clipped()
            }
            .aspectRatio(1, contentMode: .fit)

            Text(titleText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var titleText: String {
        let trimmed = item.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return trimmed.isEmpty ? "Untitled" : trimmed.joined(separator: ", ")
    }
}

private struct ThumbnailView: View {

    let filename: String?

    var body: some View {
        ZStack {
            if let uiImage = loadImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))

                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loadImage() -> UIImage? {
        guard let filename else { return nil }
        guard let dir = SharedContainer.imagesDirectoryURL() else { return nil }
        let url = dir.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}

#Preview {
    InboxView(store: LocalStore())
}
