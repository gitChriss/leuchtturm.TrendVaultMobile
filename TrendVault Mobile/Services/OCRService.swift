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

    func recognizeText(fromImageAt url: URL) async -> String {
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
}
