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

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        imageFilename: String? = nil,
        tags: [String] = [],
        source: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.imageFilename = imageFilename
        self.tags = tags
        self.source = source
    }

    func updating(
        imageFilename: String? = nil,
        tags: [String]? = nil,
        source: String? = nil
    ) -> TrendItem {
        TrendItem(
            id: id,
            createdAt: createdAt,
            modifiedAt: Date(),
            imageFilename: imageFilename ?? self.imageFilename,
            tags: tags ?? self.tags,
            source: source ?? self.source
        )
    }
}
