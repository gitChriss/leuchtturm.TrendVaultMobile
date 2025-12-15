//
//  TrendItem.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation

struct TrendItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var createdAt: Date
    var modifiedAt: Date

    // Local-first: we store images as files, and keep only a reference here.
    // Share Sheet and Photo Picker will write the image later.
    var imageFilename: String?

    var tags: [String]
    var source: String?

    // Chunk 9: OCR (stored, not live)
    var extractedText: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        imageFilename: String? = nil,
        tags: [String] = [],
        source: String? = nil,
        extractedText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.imageFilename = imageFilename
        self.tags = tags
        self.source = source
        self.extractedText = extractedText
    }

    func updating(
        imageFilename: String? = nil,
        tags: [String]? = nil,
        source: String? = nil,
        extractedText: String? = nil
    ) -> TrendItem {

        let newImageFilename = imageFilename ?? self.imageFilename

        let finalExtractedText: String?
        if let extractedText {
            finalExtractedText = extractedText
        } else if let imageFilename, imageFilename != self.imageFilename {
            // Image changed. OCR must be recalculated.
            finalExtractedText = nil
        } else {
            finalExtractedText = self.extractedText
        }

        return TrendItem(
            id: id,
            createdAt: createdAt,
            modifiedAt: Date(),
            imageFilename: newImageFilename,
            tags: tags ?? self.tags,
            source: source ?? self.source,
            extractedText: finalExtractedText
        )
    }
}
