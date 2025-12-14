//
//  StoreProtocols.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import Foundation

protocol TrendItemStore {
    func load() throws -> [TrendItem]
    func save(_ items: [TrendItem]) throws

    func add(_ item: TrendItem) throws -> [TrendItem]
    func update(_ item: TrendItem) throws -> [TrendItem]
    func delete(id: UUID) throws -> [TrendItem]
}
