//
//  TrendQuery.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import Foundation

struct TrendQuery: Equatable {

    enum DateFilterPreset: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case last7 = "Last 7 days"
        case last30 = "Last 30 days"

        var id: String { rawValue }

        func includes(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
            switch self {
            case .all:
                return true
            case .today:
                return calendar.isDate(date, inSameDayAs: now)
            case .last7:
                guard let from = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
                return date >= from
            case .last30:
                guard let from = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
                return date >= from
            }
        }
    }

    var text: String = ""
    var selectedSource: String? = nil
    var dateFilter: DateFilterPreset = .all

    var hasActiveFilters: Bool {
        let hasSearch = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSource = (selectedSource?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        let hasDate = dateFilter != .all
        return hasSearch || hasSource || hasDate
    }

    mutating func clear() {
        text = ""
        selectedSource = nil
        dateFilter = .all
    }

    func tokenize() -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        return trimmed
            .lowercased()
            .split { $0.isWhitespace || $0 == "," || $0 == ";" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return trimmed.lowercased()
    }
}
