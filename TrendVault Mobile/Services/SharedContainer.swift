//
//  SharedContainer.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation

enum SharedContainer {

    // TODO (Chunk 4): Replace with your real App Group ID once created in Xcode.
    // Example: "group.com.leuchtturm.TrendVaultMobile"
    static let appGroupID: String = "group.com.leuchtturm.TrendVaultMobile"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func fallbackDocumentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func baseURL() -> URL? {
        containerURL() ?? fallbackDocumentsURL()
    }

    static func imagesDirectoryURL() -> URL? {
        guard let base = baseURL() else { return nil }
        return base.appendingPathComponent("Images", isDirectory: true)
    }

    static func ensureImagesDirectoryExists() {
        guard let dir = imagesDirectoryURL() else { return }
        if FileManager.default.fileExists(atPath: dir.path) { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
