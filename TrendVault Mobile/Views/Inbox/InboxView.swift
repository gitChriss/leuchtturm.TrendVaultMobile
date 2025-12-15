//
//  InboxView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import SwiftUI
import Observation
import UIKit
import ImageIO

struct InboxView: View {

    @Bindable var store: LocalStore

    @State private var selectedID: UUID? = nil

    private let gridSpacing: CGFloat = 12
    private let gridHorizontalPadding: CGFloat = 16

    var body: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else if store.visibleItems.isEmpty {
                noResultsState
            } else {
                GeometryReader { geo in
                    let available = geo.size.width - (gridHorizontalPadding * 2)
                    let colWidth = floor((available - gridSpacing) / 2)

                    let columns: [GridItem] = [
                        GridItem(.fixed(colWidth), spacing: gridSpacing),
                        GridItem(.fixed(colWidth), spacing: gridSpacing)
                    ]

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(store.visibleItems) { item in
                                InboxTile(item: item, width: colWidth)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedID = item.id
                                    }
                            }
                        }
                        .padding(.horizontal, gridHorizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .navigationDestination(item: $selectedID) { id in
                        DetailView(itemID: id)
                    }
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

    private var noResultsState: some View {
        ContentUnavailableView(
            "No results",
            systemImage: "magnifyingglass",
            description: Text("Try removing a filter.")
        )
        .padding(.horizontal, 24)
    }
}

private struct InboxTile: View {

    let item: TrendItem
    let width: CGFloat

    private let radius: CGFloat = 14
    private let thumbnailHeight: CGFloat = 160

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {

            ThumbnailView(filename: item.imageFilename, targetPixelSize: 520)
                .frame(width: width, height: thumbnailHeight)
                .clipped()
                .clipShape(TopRoundedRectangle(cornerRadius: radius))

            Text(titleText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.horizontal, 10)

            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(width: width, alignment: .leading)
        .background(.thinMaterial, in: cardShape)
        .overlay(
            cardShape.strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        )
        .compositingGroup()
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
    let targetPixelSize: Int

    @State private var image: UIImage? = nil

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))

                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: filename) {
            await loadAsync()
        }
    }

    private func loadAsync() async {
        guard let filename else {
            await MainActor.run { image = nil }
            return
        }

        let key = NSString(string: "\(filename)#\(targetPixelSize)")
        if let cached = Self.cache.object(forKey: key) {
            await MainActor.run { image = cached }
            return
        }

        guard let dir = SharedContainer.imagesDirectoryURL() else {
            await MainActor.run { image = nil }
            return
        }

        let url = dir.appendingPathComponent(filename)

        let loaded: UIImage? = await Task.detached(priority: .utility) {
            downsampleImage(at: url, maxPixelSize: targetPixelSize)
        }.value

        await MainActor.run {
            if let loaded {
                Self.cache.setObject(loaded, forKey: key)
            }
            image = loaded
        }
    }

    private func downsampleImage(at url: URL, maxPixelSize: Int) -> UIImage? {
        let options: CFDictionary = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return nil
        }

        let downsampleOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}

private struct TopRoundedRectangle: Shape {

    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}
