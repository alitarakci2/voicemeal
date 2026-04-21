//
//  ImageExporter.swift
//  VoiceMeal
//

import SwiftUI
import UIKit

enum ImageExporter {
    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat = 3.0) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        return renderer.uiImage
    }

    @MainActor
    static func writePNG(_ image: UIImage, filename: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let url = tempDir.appendingPathComponent(safeName)
        try? FileManager.default.removeItem(at: url)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
