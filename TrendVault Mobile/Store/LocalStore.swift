//
//  LocalStore.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation
import Observation

@Observable
final class LocalStore {

    // MARK: - Search & Filter (Chunk 8)

    var query: TrendQuery = TrendQuery()

    var hasActiveFilters: Bool {
        query.hasActiveFilters
    }

    func clearFilters() {
        query.clear()
    }

    var availableSources: [String] {
        let sources = items
            .compactMap { $0.source?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(sources)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var visibleItems: [TrendItem] {
        let now = Date()
        let cal = Calendar.current

        let normalizedSelectedSource = query.normalize(query.selectedSource)
        let tokens = query.tokenize()

        return items.filter { item in
            guard query.dateFilter.includes(item.createdAt, now: now, calendar: cal) else { return false }

            if let normalizedSelectedSource, !normalizedSelectedSource.isEmpty {
                let itemSource = query.normalize(item.source) ?? ""
                guard itemSource == normalizedSelectedSource else { return false }
            }

            if tokens.isEmpty { return true }

            let tagHaystack = item.tags.map { query.normalize($0) ?? "" }
            let sourceHaystack = query.normalize(item.source) ?? ""

            for token in tokens {
                let matchesTag = tagHaystack.contains { $0.contains(token) }
                let matchesSource = sourceHaystack.contains(token)

                if !(matchesTag || matchesSource) {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Allowed Tags (Chunk 9.1)

    private let settings: UserDefaults
    private let allowedTagsKey: String = "allowedTagsText"

    private static let defaultAllowedTagsText: String = [
        "ad",
        "ads",
        "hook",
        "headline",
        "copy",
        "cta",
        "offer",
        "pricing",
        "layout",
        "design",
        "landingpage",
        "email",
        "subject",
        "testimonial",
        "ugc",
        "tiktok",
        "instagram",
        "facebook",
        "linkedin",
        "youtube",
        "banner"
    ].joined(separator: ", ")

    var allowedTagsText: String {
        didSet {
            persistAllowedTagsText()
        }
    }

    var allowedTagsList: [String] {
        didSet {
            syncAllowedTagsTextFromList()
        }
    }

    var allowedTags: [String] {
        allowedTagsList
            .map { Self.normalizeTag($0) }
            .filter { !$0.isEmpty }
    }

    private static func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func parseTags(from text: String) -> [String] {
        var result: [String] = []

        let parts = text
            .lowercased()
            .split { ch in
                ch.isWhitespace || ch == "," || ch == ";" || ch == "\n" || ch == "\t"
            }
            .map { String($0) }

        for raw in parts {
            let t = normalizeTag(raw)
            if t.isEmpty { continue }
            if result.contains(t) { continue }
            result.append(t)
        }

        return result
    }

    private func syncAllowedTagsTextFromList() {
        var cleaned: [String] = []
        for raw in allowedTagsList {
            let t = Self.normalizeTag(raw)
            if t.isEmpty { continue }
            if cleaned.contains(t) { continue }
            cleaned.append(t)
        }

        if cleaned != allowedTagsList {
            allowedTagsList = cleaned
            return
        }

        allowedTagsText = cleaned.joined(separator: ", ")
    }

    private func persistAllowedTagsText() {
        let trimmed = allowedTagsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            settings.set(Self.defaultAllowedTagsText, forKey: allowedTagsKey)
        } else {
            settings.set(allowedTagsText, forKey: allowedTagsKey)
        }
    }

    // MARK: - Tag Recency (Chunk 9.1 polish)

    private let tagLastUsedKey: String = "tagLastUsed"

    /// Returns normalized tag -> last used timestamp (unix time).
    private var tagLastUsed: [String: TimeInterval] {
        get {
            guard let data = settings.data(forKey: tagLastUsedKey) else { return [:] }
            guard let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                settings.set(data, forKey: tagLastUsedKey)
            }
        }
    }

    /// Call this whenever tags are saved / applied.
    func markTagsUsed(_ tags: [String]) {
        let now = Date().timeIntervalSince1970
        var current = tagLastUsed

        for raw in tags {
            let t = Self.normalizeTag(raw)
            if t.isEmpty { continue }
            current[t] = now
        }

        tagLastUsed = current
    }

    /// Returns a small integer bonus per tag to bias suggestions toward recently used tags.
    /// Higher number = higher chance to appear early.
    func recencyBonuses() -> [String: Int] {
        let current = tagLastUsed
        if current.isEmpty { return [:] }

        let sorted = current
            .sorted { $0.value > $1.value }
            .map { $0.key }

        var bonuses: [String: Int] = [:]

        for (idx, tag) in sorted.enumerated() {
            let bonus: Int
            if idx < 8 {
                bonus = 3
            } else if idx < 20 {
                bonus = 2
            } else if idx < 50 {
                bonus = 1
            } else {
                bonus = 0
            }

            if bonus > 0 {
                bonuses[tag] = bonus
            }
        }

        return bonuses
    }

    // MARK: - OCR (Chunk 9.1)

    func ensureExtractedTextIfNeeded(for itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        guard let filename = item.imageFilename,
              let dir = SharedContainer.imagesDirectoryURL() else { return }

        let existing = item.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty { return }

        let url = dir.appendingPathComponent(filename)

        let text = await OCRService.shared.recognizeText(fromImageAt: url, itemID: itemID)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalText: String = trimmed

        await MainActor.run {
            guard let latest = self.items.first(where: { $0.id == itemID }) else { return }
            self.update(latest.updating(extractedText: finalText))
        }
    }

    // MARK: - Existing Store

    private let backend: TrendItemStore
    private(set) var items: [TrendItem] = []

    var isLoading: Bool = false

    init(backend: TrendItemStore = JSONFileTrendItemStore()) {
        self.backend = backend
        self.items = []
        self.isLoading = false

        self.settings = UserDefaults(suiteName: SharedContainer.appGroupID) ?? .standard

        let stored = settings.string(forKey: allowedTagsKey)
        let initialText = (stored?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? stored!
            : Self.defaultAllowedTagsText

        self.allowedTagsText = initialText
        self.allowedTagsList = Self.parseTags(from: initialText)

        if stored == nil {
            settings.set(Self.defaultAllowedTagsText, forKey: allowedTagsKey)
        }
    }

    func reload() {
        do {
            self.items = try backend.load()
        } catch {
            self.items = []
        }
    }

    func reloadAsync() {
        Task { @MainActor in
            isLoading = true
        }

        Task.detached(priority: .userInitiated) { [backend] in
            let loaded: [TrendItem]
            do {
                loaded = try backend.load()
            } catch {
                loaded = []
            }

            await MainActor.run {
                self.items = loaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Async write operations

    func add(_ item: TrendItem) {
        Task.detached(priority: .userInitiated) { [backend] in
            let updated: [TrendItem]
            do {
                updated = try backend.add(item)
            } catch {
                return
            }

            await MainActor.run {
                self.items = updated
            }
        }
    }

    func update(_ item: TrendItem) {
        Task.detached(priority: .userInitiated) { [backend] in
            let updated: [TrendItem]
            do {
                updated = try backend.update(item)
            } catch {
                return
            }

            await MainActor.run {
                self.items = updated
            }
        }
    }

    func delete(id: UUID) {
        Task.detached(priority: .userInitiated) { [backend] in
            let updated: [TrendItem]
            do {
                updated = try backend.delete(id: id)
            } catch {
                return
            }

            await MainActor.run {
                self.items = updated
            }
        }
    }
}

// MARK: - JSON file backend (local-first, sync-ready)

final class JSONFileTrendItemStore: TrendItemStore {

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(filename: String = "trenditems.json") {

        let base = SharedContainer.baseURL()
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        self.fileURL = base.appendingPathComponent(filename)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    func load() throws -> [TrendItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let items = try decoder.decode([TrendItem].self, from: data)
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ items: [TrendItem]) throws {
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    func add(_ item: TrendItem) throws -> [TrendItem] {
        var current = try load()
        current.insert(item, at: 0)
        try save(current)
        return current
    }

    func update(_ item: TrendItem) throws -> [TrendItem] {
        var current = try load()
        if let idx = current.firstIndex(where: { $0.id == item.id }) {
            current[idx] = item
        } else {
            current.insert(item, at: 0)
        }
        current.sort { $0.createdAt > $1.createdAt }
        try save(current)
        return current
    }

    func delete(id: UUID) throws -> [TrendItem] {
        var current = try load()
        current.removeAll { $0.id == id }
        try save(current)
        return current
    }
}
