//
//  DetailView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import SwiftUI

struct DetailView: View {

    @Environment(LocalStore.self) private var store

    let itemID: UUID

    @State private var tagsText: String = ""
    @State private var sourceText: String = ""
    @State private var showingDeleteConfirm = false

    private var item: TrendItem? {
        store.items.first { $0.id == itemID }
    }

    private var imageFileURL: URL? {
        guard let filename = item?.imageFilename,
              let dir = SharedContainer.imagesDirectoryURL() else {
            return nil
        }
        return dir.appendingPathComponent(filename)
    }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        imageSection(item: item)

                        formSection(item: item)

                        actionsSection(item: item)
                    }
                    .padding()
                }
                .navigationTitle("Detail")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    tagsText = item.tags.joined(separator: ", ")
                    sourceText = item.source ?? ""
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
            if let url = imageFileURL,
               let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
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

    private func formSection(item: TrendItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(.headline)

                TextField("z. B. ads, hook, design", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { saveTags(for: item) }
                    .onChange(of: tagsText) { _, _ in
                        // Optional: live update, aber wir speichern bewusst nicht bei jedem Key-Stroke.
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
                    Button {
                        // no-op
                    } label: {
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
        // Delete image file if present
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
