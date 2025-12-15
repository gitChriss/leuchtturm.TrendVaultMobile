//
//  SharedContainer.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation

enum SharedContainer {

    static let appGroupID: String = "group.com.leuchtturm.TrendVaultMobile"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func fallbackDocumentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // Cache to avoid repeated containerURL lookups
    private static let cachedBaseURL: URL? = {
        if let groupURL = containerURL() {
            return groupURL
        }
        return fallbackDocumentsURL()
    }()

    static func baseURL() -> URL? {
        cachedBaseURL
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
