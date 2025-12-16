//
//  OCRService.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 15.12.25.
//

import Foundation
import Vision
import UIKit

final class OCRService {

    static let shared = OCRService()
    private init() {}

    private let pipeline = OCRPipeline()

    func recognizeText(fromImageAt url: URL, itemID: UUID) async -> String {
        await pipeline.run(itemID: itemID, url: url) { url in
            await self.performOCR(url: url)
        }
    }

    // MARK: - Raw OCR

    private func performOCR(url: URL) async -> String {
        await Task.detached(priority: .utility) {
            guard let image = UIImage(contentsOfFile: url.path),
                  let cgImage = image.cgImage else {
                return ""
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []

                let lines: [String] = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }

                return lines.joined(separator: "\n")
            } catch {
                return ""
            }
        }.value
    }

    // MARK: - Tag Suggestions

    /// Derives tag suggestions from OCR text.
    /// - Notes:
    ///   - Returns suggestions only, never auto-applies.
    ///   - Excludes existingTags.
    ///   - Only returns tags that exist in allowedTags (whitelist for OCR suggestions).
    ///   - Applies small recency bonuses to prefer recently used tags.
    func suggestTags(
        from extractedText: String?,
        existingTags: [String],
        allowedTags: [String],
        recencyBonuses: [String: Int]
    ) -> [String] {

        guard let extractedText, !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let normalizedExisting = Set(existingTags.map { normalizeTag($0) })
        let allowedSet = Set(allowedTags.map { normalizeTag($0) }).filter { !$0.isEmpty }

        if allowedSet.isEmpty {
            return []
        }

        let raw = extractedText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        let tokens = raw
            .lowercased()
            .split { ch in
                ch.isWhitespace || ch == "," || ch == ";" || ch == "." || ch == ":" || ch == "|" || ch == "/" || ch == "\\" || ch == "(" || ch == ")" || ch == "[" || ch == "]" || ch == "{" || ch == "}" || ch == "!" || ch == "?" || ch == "\"" || ch == "'" || ch == "„" || ch == "“" || ch == "’" || ch == "—" || ch == "-" || ch == "_" || ch == "+" || ch == "=" || ch == "*" || ch == "&" || ch == "%" || ch == "$" || ch == "#" || ch == "@" || ch == "<" || ch == ">" || ch == "~"
            }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var counts: [String: Int] = [:]

        for token in tokens {
            let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count < 2 { continue }
            if cleaned.allSatisfy({ $0.isNumber }) { continue }
            if cleaned.contains("http") || cleaned.contains("www") { continue }

            let normalized = normalizeTag(cleaned)

            if normalized.isEmpty { continue }
            if normalizedExisting.contains(normalized) { continue }
            if !allowedSet.contains(normalized) { continue }

            counts[normalized, default: 0] += 1
        }

        // Apply recency bonuses (small nudge).
        if !recencyBonuses.isEmpty {
            for (tag, bonus) in recencyBonuses {
                let normalized = normalizeTag(tag)
                guard !normalized.isEmpty else { continue }
                guard allowedSet.contains(normalized) else { continue }
                guard !normalizedExisting.contains(normalized) else { continue }
                guard bonus > 0 else { continue }

                counts[normalized, default: 0] += bonus
            }
        }

        let ranked = counts
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key.count < b.key.count
            }
            .map { $0.key }

        var result: [String] = []
        for candidate in ranked {
            result.append(candidate)
            if result.count >= 8 { break }
        }

        return result
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - OCR Pipeline (throttle + serialize + de-dupe)

private actor OCRPipeline {

    private var inFlight: Set<UUID> = []
    private var lastStart: ContinuousClock.Instant? = nil

    private let minDelay: Duration = .milliseconds(350)

    func run(
        itemID: UUID,
        url: URL,
        ocr: @Sendable (URL) async -> String
    ) async -> String {

        if inFlight.contains(itemID) {
            return ""
        }

        inFlight.insert(itemID)
        defer { inFlight.remove(itemID) }

        let clock = ContinuousClock()
        if let lastStart {
            let elapsed = clock.now - lastStart
            if elapsed < minDelay {
                let remaining = minDelay - elapsed
                try? await Task.sleep(for: remaining)
            }
        }

        lastStart = clock.now
        return await ocr(url)
    }
}
