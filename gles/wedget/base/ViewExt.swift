//
//  ViewExt.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

import SwiftUI
import UIKit
import GLKit

extension UIView {
    public func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
    public func findViewByIdentifier(_ identifier: String) -> UIView? {
        if self.accessibilityIdentifier == identifier {
            return self
        }

        for subviews in self.subviews {
            if let found = subviews.findViewByIdentifier(identifier) {
                return found
            }
        }
        return nil
    }
}

extension UIImage {
    /// 保存到相册
    public func saveToPhotoAlbum(completion: @escaping (Bool, Error?) -> Void) {
        UIImageWriteToSavedPhotosAlbum(self, nil, nil, nil)
        completion(true, nil)
    }

    /// 保存到文档目录
    public func savePngToDocuments(fileName: String) -> URL? {
        guard let data = self.pngData() else { return nil }

        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileURL = documentsPath.appendingPathComponent(
            "picture_\(timestamp).png"
        )
        do {
            try data.write(to: fileURL)
            print("✅ 图片已保存到: \(fileURL)")
            return fileURL
        } catch {
            print("❌ 保存失败: \(error)")
            return nil
        }
    }

    /// 保存到临时目录
    public func saveToTemp(fileName: String) -> URL? {
        guard let data = self.pngData() else { return nil }

        let tempPath = FileManager.default.temporaryDirectory
        let fileURL = tempPath.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            print("✅ 图片已保存到临时目录: \(fileURL)")
            return fileURL
        } catch {
            print("❌ 保存失败: \(error)")
            return nil
        }
    }

    /// 获取图片数据
    public func toData(compressionQuality: CGFloat = 1.0) -> Data? {
        if compressionQuality < 1.0 {
            return self.jpegData(compressionQuality: compressionQuality)
        } else {
            return self.pngData()
        }
    }
}
