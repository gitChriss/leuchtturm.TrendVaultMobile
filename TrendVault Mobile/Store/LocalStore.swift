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

    // MARK: - Existing Store

    private let backend: TrendItemStore
    private(set) var items: [TrendItem] = []

    var isLoading: Bool = false

    init(backend: TrendItemStore = JSONFileTrendItemStore()) {
        self.backend = backend
        self.items = []
        self.isLoading = false
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
