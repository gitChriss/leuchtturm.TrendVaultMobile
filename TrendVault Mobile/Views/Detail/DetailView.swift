//
//  DetailView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import SwiftUI
import UIKit

struct DetailView: View {

    @Environment(LocalStore.self) private var store

    let itemID: UUID

    @State private var tagsText: String = ""
    @State private var sourceText: String = ""
    @State private var showingDeleteConfirm = false

    @State private var image: UIImage? = nil
    @State private var lastLoadedFilename: String? = nil

    @State private var suggestedTags: [String] = []
    @State private var isOcrRunning: Bool = false

    @State private var showingAllowedTagsEditor: Bool = false

    private var item: TrendItem? {
        store.items.first { $0.id == itemID }
    }

    private var imageFilename: String? {
        item?.imageFilename
    }

    private var imageFileURL: URL? {
        guard let filename = item?.imageFilename,
              let dir = SharedContainer.imagesDirectoryURL() else {
            return nil
        }
        return dir.appendingPathComponent(filename)
    }

    private var resolvedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        imageSection(item: item)

                        formSection(item: item, store: store)

                        actionsSection(item: item)
                    }
                    .padding()
                }
                .navigationTitle("Detail")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    tagsText = item.tags.joined(separator: ", ")
                    sourceText = item.source ?? ""
                    recomputeSuggestions(item: item)
                }
                .onChange(of: item.extractedText) { _, _ in
                    recomputeSuggestions(item: item)
                }
                .task(id: imageFilename) {
                    await loadImageIfNeeded()
                }
                .task(id: item.extractedText) {
                    await ensureOcrIfNeeded()
                }
                .sheet(isPresented: $showingAllowedTagsEditor) {
                    NavigationStack {
                        Form {
                            Section("Allowed Tags (für OCR Vorschläge)") {
                                TextEditor(text: $store.allowedTagsText)
                                    .frame(minHeight: 180)

                                Text("Komma oder Zeilenumbruch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Section("Aktuell") {
                                Text(store.allowedTags.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .navigationTitle("Allowed Tags")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingAllowedTagsEditor = false }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nicht gefunden", systemImage: "questionmark.folder")
                    .navigationTitle("Detail")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func imageSection(item: TrendItem) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 260)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                            Text("Kein Bild")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private func formSection(item: TrendItem, store: LocalStore) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(.headline)

                TextField("z. B. ads, hook, design", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { saveTags(for: item) }

                if isOcrRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("OCR läuft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !suggestedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Vorschläge")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Edit") {
                                showingAllowedTagsEditor = true
                            }
                            .font(.caption)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    Button(tag) {
                                        applySuggestedTag(tag, item: item)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    HStack {
                        Text("Keine Vorschläge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Edit") {
                            showingAllowedTagsEditor = true
                        }
                        .font(.caption)
                    }
                }

                Text("Kommagetrennt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Quelle")
                    .font(.headline)

                TextField("Optional, z. B. instagram.com/…", text: $sourceText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit { saveSource(for: item) }
            }

            HStack {
                Text("Erstellt")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.footnote)

            HStack {
                Text("Geändert")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.footnote)
        }
    }

    private func actionsSection(item: TrendItem) -> some View {
        VStack(spacing: 10) {

            HStack(spacing: 10) {
                Button("Speichern") {
                    saveTags(for: item)
                    saveSource(for: item)
                }
                .buttonStyle(.borderedProminent)

                if let url = imageFileURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                }

                Spacer()
            }

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Eintrag löschen?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    delete(item)
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .padding(.top, 4)
    }

    // MARK: - OCR

    private func ensureOcrIfNeeded() async {
        guard let item else { return }

        let existing = item.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty {
            await MainActor.run {
                isOcrRunning = false
                recomputeSuggestions(item: item)
            }
            return
        }

        guard item.imageFilename != nil else { return }

        await MainActor.run {
            isOcrRunning = true
        }

        await store.ensureExtractedTextIfNeeded(for: itemID)

        await MainActor.run {
            isOcrRunning = false
        }
    }

    private func recomputeSuggestions(item: TrendItem) {
        let existing = resolvedTags.isEmpty ? item.tags : resolvedTags

        suggestedTags = OCRService.shared.suggestTags(
            from: item.extractedText,
            existingTags: existing,
            allowedTags: store.allowedTags
        )
    }

    private func applySuggestedTag(_ tag: String, item: TrendItem) {
        let normalizedExisting = Set(resolvedTags.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })

        let norm = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { return }
        guard !normalizedExisting.contains(norm) else { return }

        var updated = resolvedTags
        updated.append(tag)

        tagsText = updated.joined(separator: ", ")
        saveTags(for: item)

        recomputeSuggestions(item: item)
    }

    // MARK: - Image loading

    private func loadImageIfNeeded() async {
        guard let filename = imageFilename else {
            await MainActor.run {
                image = nil
                lastLoadedFilename = nil
            }
            return
        }

        if lastLoadedFilename == filename, image != nil {
            return
        }

        guard let dir = SharedContainer.imagesDirectoryURL() else {
            await MainActor.run {
                image = nil
                lastLoadedFilename = filename
            }
            return
        }

        let url = dir.appendingPathComponent(filename)

        let loaded: UIImage? = await Task.detached(priority: .utility) {
            UIImage(contentsOfFile: url.path)
        }.value

        await MainActor.run {
            image = loaded
            lastLoadedFilename = filename
        }
    }

    // MARK: - Actions

    private func saveTags(for item: TrendItem) {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        store.update(item.updating(tags: tags))
    }

    private func saveSource(for item: TrendItem) {
        let value = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: String? = value.isEmpty ? nil : value
        store.update(item.updating(source: source))
    }

    private func delete(_ item: TrendItem) {
        if let url = imageFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        store.delete(id: item.id)
    }
}

#Preview {
    NavigationStack {
        DetailView(itemID: UUID())
            .environment(LocalStore())
    }
}
