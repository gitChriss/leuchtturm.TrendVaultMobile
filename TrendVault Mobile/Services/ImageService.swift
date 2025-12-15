//
//  ImageService.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation
import UniformTypeIdentifiers

final class ImageService {

    static let shared = ImageService()

    private init() {}

    func saveImageData(_ data: Data, preferredFileExtension: String = "jpg") -> String? {
        let filename = "trenditem-\(UUID().uuidString).\(preferredFileExtension)"

        SharedContainer.ensureImagesDirectoryExists()

        guard let dir = SharedContainer.imagesDirectoryURL() else {
            return nil
        }

        let url = dir.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }

    func fileExtension(for uti: UTType?) -> String {
        guard let uti else { return "jpg" }
        if uti.conforms(to: .png) { return "png" }
        if uti.conforms(to: .jpeg) { return "jpg" }
        if uti.conforms(to: .heic) { return "heic" }
        return "jpg"
    }
}
