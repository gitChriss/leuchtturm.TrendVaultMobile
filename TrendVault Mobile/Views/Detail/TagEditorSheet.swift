//
//  TagEditorSheet.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI

struct TagEditorSheet: View {

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
