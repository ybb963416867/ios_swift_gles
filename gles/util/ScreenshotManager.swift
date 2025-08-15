//
//  ScreenshotManager.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/15.
//

import UIKit
import GLKit
import Photos

// MARK: - 截图管理器
class ScreenshotManager {
    
    // MARK: - Properties
    
    static let shared = ScreenshotManager()
    private let documentsDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }
    
    // MARK: - Public Methods
    func captureScreenshot(from fbo: GLuint, width: Int, height: Int) -> UIImage? {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
        
        let pixelDataSize = width * height * 4
        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelDataSize)
        defer { pixelData.deallocate() }
        
        // 直接读取 BGRA，避免手动交换通道
        glReadPixels(
            0, 0,
            GLsizei(width), GLsizei(height),
            GLenum(GL_BGRA),
            GLenum(GL_UNSIGNED_BYTE),
            pixelData
        )
        
        let image = createUIImage(from: pixelData, width: width, height: height)
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        
        return image
    }

    private func createUIImage(from pixelData: UnsafeMutablePointer<UInt8>, width: Int, height: Int) -> UIImage? {
        // 垂直翻转
        let flippedData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        defer { flippedData.deallocate() }
        
        for y in 0..<height {
            let flippedY = height - 1 - y
            memcpy(
                flippedData.advanced(by: flippedY * width * 4),
                pixelData.advanced(by: y * width * 4),
                width * 4
            )
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // BGRA + premultiplied alpha
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let context = CGContext(
            data: flippedData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("无法创建 CGContext")
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            print("无法创建 CGImage")
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }

    
    /// 保存图片到文档目录
    func saveToDocuments(_ image: UIImage, filename: String? = nil) -> URL? {
        let fileName = filename ?? generateFileName(extension: "png")
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        guard let data = image.pngData() else {
            print("无法生成 PNG 数据")
            return nil
        }
        
        do {
            try data.write(to: fileURL)
            print("截图已保存到: \(fileURL.path)")
            return fileURL
        } catch {
            print("保存截图失败: \(error)")
            return nil
        }
    }
    
    /// 保存图片到相册
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, NSError(
                        domain: "ScreenshotManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "没有相册访问权限"]
                    ))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    /// 获取文档目录中的所有截图
    func getAllScreenshots() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil
            )
            return files.filter { url in
                let path = url.path.lowercased()
                return path.contains("screenshot") && (path.hasSuffix(".png") || path.hasSuffix(".jpg"))
            }
        } catch {
            print("获取截图列表失败: \(error)")
            return []
        }
    }
    
    /// 删除截图
    func deleteScreenshot(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("删除截图失败: \(error)")
            return false
        }
    }
    
    private func generateFileName(extension ext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return "screenshot_\(timestamp).\(ext)"
    }
}
