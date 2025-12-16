//
//  ImageViewerSheet.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI
import UIKit

struct ImageViewerSheet: View {

    @Environment(\.dismiss) private var dismiss
    let image: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableImage(image: image)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    ContentUnavailableView("Kein Bild", systemImage: "photo")
                }
            }
            .navigationTitle("Bild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ZoomableImage: UIViewRepresentable {

    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 5.0
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scroll.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
