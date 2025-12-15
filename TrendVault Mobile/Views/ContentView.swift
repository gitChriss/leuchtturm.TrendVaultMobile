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

    // Chunk 3 – Screenshot Import
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting: Bool = false

    // Chunk 5 – Capture Screen
    @State private var pendingCapture: PendingCapture? = nil

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
            .onAppear {
                store.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                store.reload()
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

                    await MainActor.run {
                        // Open Capture Screen for tagging before saving the TrendItem.
                        pendingCapture = PendingCapture(
                            imageFilename: filename,
                            initialTags: [defaultImportTag],
                            initialSource: "photo_picker"
                        )
                    }

                    // If multiple images were selected, we only open one capture at a time.
                    // Stop here so the user can save, then they can import the next batch.
                    break

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

// MARK: - Pending capture model

private struct PendingCapture: Identifiable {
    let id = UUID()
    let imageFilename: String
    let initialTags: [String]
    let initialSource: String?
}

#Preview {
    ContentView(store: LocalStore())
}
