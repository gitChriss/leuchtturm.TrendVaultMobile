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

    private let backend: TrendItemStore
    private(set) var items: [TrendItem] = []

    init(backend: TrendItemStore = JSONFileTrendItemStore()) {
        self.backend = backend
        do {
            self.items = try backend.load()
        } catch {
            self.items = []
        }
    }

    func reload() {
        do {
            self.items = try backend.load()
        } catch {
            self.items = []
        }
    }

    func add(_ item: TrendItem) {
        do {
            self.items = try backend.add(item)
        } catch {
            // keep current state if saving fails
        }
    }

    func update(_ item: TrendItem) {
        do {
            self.items = try backend.update(item)
        } catch {
        }
    }

    func delete(id: UUID) {
        do {
            self.items = try backend.delete(id: id)
        } catch {
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
