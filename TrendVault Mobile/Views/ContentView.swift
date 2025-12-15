//
//  ContentView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {

    @Bindable var store: LocalStore

    // Import
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting: Bool = false

    // Capture
    @State private var pendingCapture: PendingCapture? = nil

    // Filter UI
    @State private var isFilterSheetPresented: Bool = false

    private let defaultImportTag = "inbox"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                if store.hasActiveFilters {
                    FilterChipsRow(
                        query: store.query,
                        onClearSearch: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.query.text = ""
                            }
                        },
                        onClearSource: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.query.selectedSource = nil
                            }
                        },
                        onClearDate: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.query.dateFilter = .all
                            }
                        },
                        onClearAll: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.clearFilters()
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Group {
                    if store.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        InboxView(store: store)
                            .navigationDestination(for: UUID.self) { id in
                                DetailView(itemID: id)
                            }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: store.hasActiveFilters)
            .searchable(
                text: $store.query.text,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedPickerItems,
                        maxSelectionCount: 0,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if isImporting {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isImporting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isFilterSheetPresented = true
                    } label: {
                        Image(
                            systemName: store.hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .onChange(of: selectedPickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                importPickerItems(newItems)
            }
            .onAppear {
                store.reloadAsync()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )
            ) { _ in
                store.reloadAsync()
            }
            .sheet(item: $pendingCapture) { capture in
                CaptureView(
                    imageFilename: capture.imageFilename,
                    initialTags: capture.initialTags,
                    initialSource: capture.initialSource
                ) { tags, source in
                    let newItem = TrendItem(
                        imageFilename: capture.imageFilename,
                        tags: tags,
                        source: source
                    )
                    store.add(newItem)
                }
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                filterSheet
            }
        }
        .environment(store)
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Picker("Range", selection: $store.query.dateFilter) {
                        ForEach(TrendQuery.DateFilterPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Source") {
                    Picker("Source", selection: $store.query.selectedSource) {
                        Text("All Sources").tag(Optional<String>.none)
                        ForEach(store.availableSources, id: \.self) { source in
                            Text(source).tag(Optional(source))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isFilterSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Import

    private func importPickerItems(_ items: [PhotosPickerItem]) {
        isImporting = true

        Task {
            let single = items.count == 1

            for (index, item) in items.enumerated() {
                do {
                    let data = try await item.loadTransferable(type: Data.self)
                    guard let data else { continue }

                    let ext = ImageService.shared.fileExtension(
                        for: item.supportedContentTypes.first
                    )

                    guard let filename =
                        ImageService.shared.saveImageData(data, preferredFileExtension: ext)
                    else { continue }

                    if single {
                        await MainActor.run {
                            pendingCapture = PendingCapture(
                                imageFilename: filename,
                                initialTags: [defaultImportTag],
                                initialSource: "photo_picker"
                            )
                        }
                        break
                    } else {
                        let newItem = TrendItem(
                            imageFilename: filename,
                            tags: [defaultImportTag],
                            source: "photo_picker"
                        )
                        await MainActor.run {
                            store.add(newItem)
                        }
                    }

                    if single && index == 0 { break }

                } catch {
                    continue
                }
            }

            await MainActor.run {
                selectedPickerItems = []
                isImporting = false
            }
        }
    }
}

// MARK: - Filter Chips Row

private struct FilterChipsRow: View {

    let query: TrendQuery

    let onClearSearch: () -> Void
    let onClearSource: () -> Void
    let onClearDate: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {

                if !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chip(
                        text: "Search: \(truncate(query.text))",
                        systemImage: "xmark.circle"
                    ) {
                        onClearSearch()
                    }
                }

                if let source = query.selectedSource,
                   !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chip(
                        text: "Source: \(truncate(source))",
                        systemImage: "xmark.circle"
                    ) {
                        onClearSource()
                    }
                }

                if query.dateFilter != .all {
                    chip(
                        text: query.dateFilter.rawValue,
                        systemImage: "xmark.circle"
                    ) {
                        onClearDate()
                    }
                }

                chip(
                    text: "Clear all",
                    systemImage: "xmark.circle"
                ) {
                    onClearAll()
                }
            }
            .font(.caption)
            .padding(.vertical, 2)
        }
    }

    private func truncate(_ text: String, max: Int = 20) -> String {
        guard text.count > max else { return text }
        let idx = text.index(text.startIndex, offsetBy: max)
        return String(text[..<idx]) + "…"
    }

    private func chip(
        text: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                    .lineLimit(1)
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Capture

private struct PendingCapture: Identifiable {
    let id = UUID()
    let imageFilename: String
    let initialTags: [String]
    let initialSource: String?
}

#Preview {
    ContentView(store: LocalStore())
}
