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
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID

    @State private var tagsText: String = ""
    @State private var sourceText: String = ""

    @State private var showingDeleteConfirm: Bool = false

    @State private var image: UIImage? = nil
    @State private var lastLoadedFilename: String? = nil

    @State private var suggestedTags: [String] = []
    @State private var isTextRecognitionRunning: Bool = false

    @State private var showingAllowedTagsEditor: Bool = false

    @State private var showingImageViewer: Bool = false

    @State private var showingTagEditor: Bool = false
    @State private var editingTags: [String] = []

    @State private var sourceAutosaveTask: Task<Void, Never>? = nil

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

    private var normalizedResolvedTags: [String] {
        sanitizeList(resolvedTags)
    }

    private var resolvedSource: String? {
        let v = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        imageSection()

                        metaSection(item: item)

                        tagsSection(item: item)

                        suggestionsSection()

                        sourceSection()

                        Spacer(minLength: 8)
                    }
                    .padding()
                }
                .navigationTitle("Detail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if let url = imageFileURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share")
                        } else {
                            Button { } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .disabled(true)
                            .accessibilityLabel("Share")
                        }
                    }
                }
                .confirmationDialog(
                    "Eintrag löschen?",
                    isPresented: $showingDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Löschen", role: .destructive) {
                        delete(item)
                        dismiss()
                    }
                    Button("Abbrechen", role: .cancel) {}
                }
                .onAppear {
                    tagsText = item.tags.joined(separator: ", ")
                    sourceText = item.source ?? ""
                    recomputeSuggestions(item: item)
                }
                .onChange(of: item.extractedText) { _, _ in
                    recomputeSuggestions(itemID: itemID)
                }
                .onChange(of: store.allowedTagsList) { _, _ in
                    recomputeSuggestions(itemID: itemID)
                }
                .task(id: imageFilename) {
                    await loadImageIfNeeded()
                }
                .task(id: item.extractedText) {
                    await ensureTextRecognitionIfNeeded()
                }
                .sheet(isPresented: $showingAllowedTagsEditor) {
                    AllowedTagsEditorView(tags: $store.allowedTagsList)
                }
                .sheet(isPresented: $showingImageViewer) {
                    ImageViewerSheet(image: image)
                }
                .sheet(isPresented: $showingTagEditor) {
                    TagEditorSheet(
                        tags: $editingTags,
                        suggestions: suggestedTags,
                        onAddSuggestion: { tag in
                            let t = sanitizeTag(tag)
                            guard !t.isEmpty else { return }
                            if !editingTags.contains(t) {
                                editingTags.append(t)
                            }
                        },
                        onDone: { final in
                            let cleaned = sanitizeList(final)
                            tagsText = cleaned.joined(separator: ", ")
                            saveTagsIfChanged(itemID: itemID, tags: cleaned)
                            recomputeSuggestions(itemID: itemID)
                        }
                    )
                }
                .onDisappear {
                    sourceAutosaveTask?.cancel()
                    sourceAutosaveTask = nil
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
    private func imageSection() -> some View {
        Group {
            if let image {
                Button {
                    showingImageViewer = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
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

    private func metaSection(item: TrendItem) -> some View {
        VStack(spacing: 6) {
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

    private func tagsSection(item: TrendItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                Text("Tags")
                    .font(.headline)

                Spacer()

                Button {
                    editingTags = sanitizeList(resolvedTags.isEmpty ? item.tags : resolvedTags)
                    showingTagEditor = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit tags")
            }

            if normalizedResolvedTags.isEmpty {
                Text("Keine Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(normalizedResolvedTags, id: \.self) { tag in
                        TagChip(title: tag)
                    }
                }
            }
        }
    }

    private func suggestionsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 10) {
                Text("Vorschläge")
                    .font(.headline)

                Spacer()

                Button {
                    showingAllowedTagsEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Allowed tags")
            }

            if isTextRecognitionRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Texterkennung läuft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if suggestedTags.isEmpty {
                Text("Keine Vorschläge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button(tag) {
                                applySuggestedTag(tag, itemID: itemID)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func sourceSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Quelle")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("z. B. instagram.com/…", text: $sourceText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit {
                        saveSourceIfChanged(itemID: itemID, source: resolvedSource)
                    }
                    .onChange(of: sourceText) { _, _ in
                        scheduleSourceAutosave()
                    }

                if let url = normalizedSourceURL(from: sourceText) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Open source")
                }
            }

            if let host = normalizedSourceHost(from: sourceText) {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Text recognition

    private func ensureTextRecognitionIfNeeded() async {
        guard let item else { return }

        let existing = item.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty {
            await MainActor.run {
                isTextRecognitionRunning = false
                recomputeSuggestions(itemID: itemID)
            }
            return
        }

        guard item.imageFilename != nil else { return }

        await MainActor.run {
            isTextRecognitionRunning = true
        }

        await store.ensureExtractedTextIfNeeded(for: itemID)

        await MainActor.run {
            isTextRecognitionRunning = false
        }
    }

    private func recomputeSuggestions(itemID: UUID) {
        guard let item = store.items.first(where: { $0.id == itemID }) else {
            suggestedTags = []
            return
        }

        let existing = normalizedResolvedTags.isEmpty ? item.tags : normalizedResolvedTags

        suggestedTags = OCRService.shared.suggestTags(
            from: item.extractedText,
            existingTags: existing,
            allowedTags: store.allowedTags,
            recencyBonuses: store.recencyBonuses
        )
    }

    private func recomputeSuggestions(item: TrendItem) {
        let existing = normalizedResolvedTags.isEmpty ? item.tags : normalizedResolvedTags

        suggestedTags = OCRService.shared.suggestTags(
            from: item.extractedText,
            existingTags: existing,
            allowedTags: store.allowedTags,
            recencyBonuses: store.recencyBonuses
        )
    }

    private func applySuggestedTag(_ tag: String, itemID: UUID) {
        let norm = sanitizeTag(tag)
        guard !norm.isEmpty else { return }

        var current = normalizedResolvedTags
        if current.isEmpty {
            let base = store.items.first(where: { $0.id == itemID })?.tags ?? []
            current = sanitizeList(base)
        }

        if current.contains(norm) { return }

        current.append(norm)
        tagsText = current.joined(separator: ", ")
        saveTagsIfChanged(itemID: itemID, tags: current)
        recomputeSuggestions(itemID: itemID)
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

    // MARK: - Auto save (debounce)

    private func scheduleSourceAutosave() {
        sourceAutosaveTask?.cancel()

        let currentText = sourceText
        let id = itemID

        sourceAutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)

            if Task.isCancelled { return }
            if currentText != self.sourceText { return }

            let source = self.resolvedSource
            self.saveSourceIfChanged(itemID: id, source: source)
        }
    }

    // MARK: - Save actions

    private func saveTagsIfChanged(itemID: UUID, tags: [String]) {
        guard let latest = store.items.first(where: { $0.id == itemID }) else { return }
        let cleaned = sanitizeList(tags)

        if cleaned == sanitizeList(latest.tags) {
            return
        }

        store.update(latest.updating(tags: cleaned))
    }

    private func saveSourceIfChanged(itemID: UUID, source: String?) {
        guard let latest = store.items.first(where: { $0.id == itemID }) else { return }

        let newValue = (source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let oldValue = (latest.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if newValue == oldValue {
            return
        }

        let final: String? = newValue.isEmpty ? nil : newValue
        store.update(latest.updating(source: final))
    }

    // MARK: - Delete

    private func delete(_ item: TrendItem) {
        if let url = imageFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        store.delete(id: item.id)
    }

    // MARK: - Source helpers

    private func normalizedSourceURL(from raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), url.scheme != nil {
            return url
        }

        let prefixed = "https://\(value)"
        if let url = URL(string: prefixed), url.scheme != nil {
            return url
        }

        return nil
    }

    private func normalizedSourceHost(from raw: String) -> String? {
        guard let url = normalizedSourceURL(from: raw) else { return nil }
        return url.host
    }

    // MARK: - Sanitizing

    private func sanitizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func sanitizeList(_ list: [String]) -> [String] {
        var result: [String] = []
        for raw in list {
            let t = sanitizeTag(raw)
            if t.isEmpty { continue }
            if result.contains(t) { continue }
            result.append(t)
        }
        return result
    }
}

#Preview {
    NavigationStack {
        DetailView(itemID: UUID())
            .environment(LocalStore())
    }
}
