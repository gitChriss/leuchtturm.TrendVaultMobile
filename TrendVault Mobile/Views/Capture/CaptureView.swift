//
//  CaptureView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import SwiftUI
import UIKit

struct CaptureView: View {

    @Environment(\.dismiss) private var dismiss

    let imageFilename: String
    let initialTags: [String]
    let initialSource: String?
    let onSave: (_ tags: [String], _ source: String?) -> Void

    @State private var tagsText: String = ""
    @State private var sourceText: String = ""

    private var resolvedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !resolvedTags.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    if let uiImage = loadImage(filename: imageFilename) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ContentUnavailableView(
                            "Image not found",
                            systemImage: "photo",
                            description: Text("The file could not be loaded.")
                        )
                    }
                }

                Section("Tags") {
                    TextField("e.g. ad, hook, layout", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Source (optional)") {
                    TextField("e.g. instagram, tiktok, website", text: $sourceText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Capture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(resolvedTags, source.isEmpty ? nil : source)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                tagsText = initialTags.joined(separator: ", ")
                sourceText = initialSource ?? ""
            }
        }
    }

    // MARK: - Image loading (matches ImageService.saveImageData)

    private func loadImage(filename: String) -> UIImage? {
        guard let dir = SharedContainer.imagesDirectoryURL() else { return nil }
        let url = dir.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}
