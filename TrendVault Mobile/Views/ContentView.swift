//
//  ContentView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {

    @Bindable var store: LocalStore

    // Chunk 3 – Screenshot Import
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting: Bool = false

    private let defaultImportTag = "inbox"

    var body: some View {
        NavigationStack {
            List {
                Section("Items") {
                    if store.items.isEmpty {
                        Text("No items yet.")
                    } else {
                        ForEach(store.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.tags.isEmpty ? "Untitled" : item.tags.joined(separator: ", "))
                                    .font(.headline)
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.delete(id: store.items[idx].id)
                            }
                        }
                    }
                }

                Section("Debug") {
                    Button("Add sample item") {
                        let sample = TrendItem(tags: ["ad", "hook"], source: "debug")
                        store.add(sample)
                    }

                    Button("Reload from disk") {
                        store.reload()
                    }
                }
            }
            .navigationTitle("TrendVault")
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
            }
            .onChange(of: selectedPickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                importPickerItems(newItems)
            }
        }
    }

    // MARK: - Import

    private func importPickerItems(_ items: [PhotosPickerItem]) {
        isImporting = true

        Task {
            for item in items {
                do {
                    let data = try await item.loadTransferable(type: Data.self)

                    guard let data else { continue }

                    let preferredUTI = item.supportedContentTypes.first
                    let ext = ImageService.shared.fileExtension(for: preferredUTI)

                    guard let filename = ImageService.shared.saveImageData(data, preferredFileExtension: ext) else {
                        continue
                    }

                    let newItem = TrendItem(
                        imageFilename: filename,
                        tags: [defaultImportTag],
                        source: "photo_picker"
                    )

                    await MainActor.run {
                        store.add(newItem)
                    }
                } catch {
                    // ignore single failures and continue importing
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

#Preview {
    ContentView(store: LocalStore())
}
