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
    @State private var showingDeleteConfirm = false

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

                        imageSection(item: item)

                        metaSection(item: item)

                        tagsSection(item: item)

                        suggestionsSection(item: item)

                        sourceSection(item: item)

                        Spacer(minLength: 10)
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
                    recomputeSuggestions(item: item)
                }
                .onChange(of: store.allowedTagsList) { _, _ in
                    recomputeSuggestions(item: item)
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
    private func imageSection(item: TrendItem) -> some View {
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

            HStack(alignment: .center, spacing: 10) {
                Text("Tags")
                    .font(.headline)

                Spacer()

                SmallPillButton(systemName: "square.and.pencil") {
                    editingTags = sanitizeList(resolvedTags.isEmpty ? item.tags : resolvedTags)
                    showingTagEditor = true
                }
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

    private func suggestionsSection(item: TrendItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("Vorschläge")
                    .font(.headline)

                Spacer()

                SmallPillButton(systemName: "slider.horizontal.3") {
                    showingAllowedTagsEditor = true
                }
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
                        ForEach(Array(suggestedTags.enumerated()), id: \.offset) { index, tag in
                            suggestionChip(tag: tag, index: index) {
                                applySuggestedTag(tag, itemID: itemID)
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.45)
                                    .onEnded { _ in
                                        showingAllowedTagsEditor = true
                                    }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func sourceSection(item: TrendItem) -> some View {
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
                    SmallPillButton(systemName: "safari") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            if let host = normalizedSourceHost(from: sourceText) {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chips

    @ViewBuilder
    private func suggestionChip(tag: String, index: Int, action: @escaping () -> Void) -> some View {
        if index == 0 {
            Button(tag) { action() }
                .buttonStyle(.borderedProminent)
        } else if index == 1 {
            Button(tag) { action() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
        } else {
            Button(tag) { action() }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
            recencyBonuses: store.recencyBonuses()
        )
    }

    private func recomputeSuggestions(item: TrendItem) {
        let existing = normalizedResolvedTags.isEmpty ? item.tags : normalizedResolvedTags

        suggestedTags = OCRService.shared.suggestTags(
            from: item.extractedText,
            existingTags: existing,
            allowedTags: store.allowedTags,
            recencyBonuses: store.recencyBonuses()
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

        store.markTagsUsed(cleaned)
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

    // MARK: - Share

    private func share(url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return
        }
        root.present(av, animated: true)
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

// MARK: - Small pill button (matches Inbox vibe)

private struct SmallPillButton: View {

    let systemName: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag chip

private struct TagChip: View {
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

// MARK: - FlowLayout (SwiftUI Layout)

private struct FlowLayout: Layout {

    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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

// MARK: - Tag editor sheet (assigned tags + suggestions)

private struct TagEditorSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var tags: [String]

    let suggestions: [String]
    let onAddSuggestion: (String) -> Void

    let onDone: ([String]) -> Void

    @State private var isEditingTag: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var editingValue: String = ""

    @State private var newTagValue: String = ""

    var body: some View {
        NavigationStack {
            List {

                if !availableSuggestions.isEmpty {
                    Section("Vorschläge aus Texterkennung") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableSuggestions, id: \.self) { tag in
                                    Button(tag) {
                                        onAddSuggestion(tag)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Tags") {
                    if tags.isEmpty {
                        ContentUnavailableView(
                            "Keine Tags",
                            systemImage: "tag",
                            description: Text("Füge Tags hinzu.")
                        )
                    } else {
                        ForEach(Array(tags.enumerated()), id: \.offset) { index, value in
                            HStack {
                                Text(value)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                beginEdit(index: index, currentValue: value)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }

                Section("Neuer Tag") {
                    HStack {
                        TextField("z. B. hook", text: $newTagValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { addNewTag() }

                        Button {
                            addNewTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(sanitizedTag(newTagValue).isEmpty)
                    }
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDone(tags)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isEditingTag) {
                NavigationStack {
                    Form {
                        Section("Tag bearbeiten") {
                            TextField("Tag", text: $editingValue)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Section {
                            Button("Save") { commitEdit() }
                                .disabled(sanitizedTag(editingValue).isEmpty)

                            Button("Cancel", role: .cancel) {
                                isEditingTag = false
                            }
                        }
                    }
                    .navigationTitle("Edit Tag")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { commitEdit() }
                                .disabled(sanitizedTag(editingValue).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                tags = sanitizeList(tags)
            }
            .onChange(of: tags) { _, newValue in
                tags = sanitizeList(newValue)
            }
        }
    }

    private var availableSuggestions: [String] {
        let current = Set(tags.map { sanitizedTag($0) })
        return suggestions
            .map { sanitizedTag($0) }
            .filter { !$0.isEmpty }
            .filter { !current.contains($0) }
    }

    private func addNewTag() {
        let t = sanitizedTag(newTagValue)
        guard !t.isEmpty else { return }
        if !tags.contains(t) {
            tags.append(t)
        }
        newTagValue = ""
    }

    private func beginEdit(index: Int, currentValue: String) {
        editingIndex = index
        editingValue = currentValue
        isEditingTag = true
    }

    private func commitEdit() {
        guard let idx = editingIndex else {
            isEditingTag = false
            return
        }

        let t = sanitizedTag(editingValue)
        guard !t.isEmpty else { return }

        if tags.enumerated().contains(where: { $0.offset != idx && $0.element == t }) {
            tags.remove(at: idx)
        } else {
            tags[idx] = t
        }

        isEditingTag = false
    }

    private func delete(at index: Int) {
        guard tags.indices.contains(index) else { return }
        tags.remove(at: index)
    }

    private func delete(at offsets: IndexSet) {
        tags.remove(atOffsets: offsets)
    }

    private func move(from source: IndexSet, to destination: Int) {
        tags.move(fromOffsets: source, toOffset: destination)
    }

    private func sanitizedTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func sanitizeList(_ list: [String]) -> [String] {
        var result: [String] = []
        for raw in list {
            let t = sanitizedTag(raw)
            if t.isEmpty { continue }
            if result.contains(t) { continue }
            result.append(t)
        }
        return result
    }
}

// MARK: - Image viewer sheet (fullscreen + zoom)

private struct ImageViewerSheet: View {

    @Environment(\.dismiss) private var dismiss
    let image: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableImage(image: image)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    ContentUnavailableView("Kein Bild", systemImage: "photo")
                }
            }
            .navigationTitle("Bild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {

    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 5.0
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scroll.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
