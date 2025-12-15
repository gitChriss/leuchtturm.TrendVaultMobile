//
//  ShareViewController.swift
//  TrendVaultShare
//
//  Created by Christian Ruppelt on 14.12.25.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private let appGroupID = "group.com.leuchtturm.TrendVaultMobile"
    private let defaultTag = "inbox"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        handleShare()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.isUserInteractionEnabled = false

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Saving to TrendVault…"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        view.addSubview(spinner)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -8),

            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func handleShare() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let providers = item.attachments,
            !providers.isEmpty
        else {
            finish()
            return
        }

        for provider in providers {

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                    self?.handleLoadedItem(item)
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    self?.handleLoadedItem(item)
                }
                return
            }
        }

        finish()
    }

    private func handleLoadedItem(_ item: NSSecureCoding?) {
        if let url = item as? URL {
            importImage(from: url)
            return
        }

        if let image = item as? UIImage {
            importUIImage(image)
            return
        }

        if let data = item as? Data {
            importImageData(data, ext: "jpg")
            return
        }

        finish()
    }

    private func importImage(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension.lowercased()
            importImageData(data, ext: ext)
        } catch {
            finish()
        }
    }

    private func importUIImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            finish()
            return
        }
        importImageData(data, ext: "jpg")
    }

    private func importImageData(_ data: Data, ext: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            finish()
            return
        }

        let imagesDir = container.appendingPathComponent("Images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }

        let filename = "trenditem-\(UUID().uuidString).\(ext)"
        let imageURL = imagesDir.appendingPathComponent(filename)

        do {
            try data.write(to: imageURL, options: [.atomic])
        } catch {
            finish()
            return
        }

        let newItem = TrendItem(
            id: UUID(),
            createdAt: Date(),
            modifiedAt: Date(),
            imageFilename: filename,
            tags: [defaultTag],
            source: "share_extension",
            extractedText: nil
        )

        let jsonURL = container.appendingPathComponent("trenditems.json")
        appendTrendItem(newItem, to: jsonURL)

        finish()
    }

    private func appendTrendItem(_ item: TrendItem, to url: URL) {
        var current: [TrendItem] = []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([TrendItem].self, from: data) {
            current = decoded
        }

        current.insert(item, at: 0)

        if let data = try? encoder.encode(current) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private func finish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}

// Minimal duplicate model for the extension target.
// Keep in sync with app model.
private struct TrendItem: Codable {
    var id: UUID
    var createdAt: Date
    var modifiedAt: Date
    var imageFilename: String?
    var tags: [String]
    var source: String?
    var extractedText: String?
}
