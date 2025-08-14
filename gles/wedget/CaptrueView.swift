//
//  ViewRecorder.swift
//  swift_gles
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - 视图录制器
class ViewRecorder: ObservableObject {
    @Published var isRecording = false
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var frameCount: Int64 = 0
    
    // 录制参数
    private let frameRate: Double = 30.0
    private var outputURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recorded_view_\(Date().timeIntervalSince1970).mp4"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    func startRecording(view: UIView, frame: CGRect) {
        guard !isRecording else { return }
        
        setupAssetWriter(size: frame.size)
        isRecording = true
        startTime = CACurrentMediaTime()
        frameCount = 0
        
        // 创建显示链接进行帧捕获
        displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
        displayLink?.preferredFramesPerSecond = Int(frameRate)
        displayLink?.add(to: .main, forMode: .common)
        
        // 存储要录制的视图和区域
        recordingView = view
        recordingFrame = frame
        
        print("开始录制，视图: \(view), 区域: \(frame)")
    }
    
    private var recordingView: UIView?
    private var recordingFrame: CGRect = .zero
    
    func stopRecording() {
        guard isRecording else { return }
        
        displayLink?.invalidate()
        displayLink = nil
        
        assetWriterInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.isRecording = false
                if let url = self?.assetWriter?.outputURL {
                    print("录制完成，文件保存在: \(url)")
                    print("文件路径: \(url.path)")
                }
                self?.cleanup()
            }
        }
    }
    
    private func setupAssetWriter(size: CGSize) {
        do {
            // 删除已存在的文件
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let outputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
                ]
            ]
            
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput!,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            
            if let input = assetWriterInput {
                assetWriter?.add(input)
            }
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            
        } catch {
            print("设置录制器失败: \(error)")
        }
    }
    
    @objc private func captureFrame() {
        guard let view = recordingView,
              let input = assetWriterInput,
              let adaptor = pixelBufferAdaptor,
              input.isReadyForMoreMediaData else { return }
        
        let currentTime = CACurrentMediaTime() - startTime
        let presentationTime = CMTime(seconds: currentTime, preferredTimescale: 600)
        
        autoreleasepool {
            if let pixelBuffer = captureViewToPixelBuffer(view: view, frame: recordingFrame) {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                frameCount += 1
            }
        }
    }
    
    private func captureViewToPixelBuffer(view: UIView, frame: CGRect) -> CVPixelBuffer? {
        print("frame = \(frame)")
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(width: frame.width * scale, height: frame.height * scale)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(scaledSize.width),
            Int(scaledSize.height),
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("创建像素缓冲区失败")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(scaledSize.width),
            height: Int(scaledSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let cgContext = context else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            print("创建CGContext失败")
            return nil
        }
        
        // 关键修复：正确处理坐标系统
        cgContext.saveGState()
        
        // 翻转Y轴以匹配UIView坐标系
        cgContext.translateBy(x: 0, y: scaledSize.height)
        cgContext.scaleBy(x: scale, y: -scale)
        
        // 平移到目标区域
        cgContext.translateBy(x: -frame.origin.x, y: -frame.origin.y)
        
        // 设置裁剪区域
        cgContext.clip(to: frame)
        
        // 渲染视图
        view.layer.render(in: cgContext)
        
        cgContext.restoreGState()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    // 获取文档目录下的所有MP4文件
    func getRecordedVideos() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath,
                                                                      includingPropertiesForKeys: nil)
            return fileURLs.filter { $0.pathExtension.lowercased() == "mp4" }
        } catch {
            print("获取录制文件失败: \(error)")
            return []
        }
    }
    
    private func cleanup() {
        assetWriter = nil
        assetWriterInput = nil
        pixelBufferAdaptor = nil
        recordingView = nil
        recordingFrame = .zero
    }
}

// MARK: - 获取视图frame的扩展
extension View {
    func captureFrame(in coordinateSpace: CoordinateSpace = .global, _ frame: @escaping (CGRect) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        frame(geometry.frame(in: coordinateSpace))
                    }
                    .onChange(of: geometry.frame(in: coordinateSpace)) { newFrame in
                        frame(newFrame)
                    }
            }
        )
    }
}

// MARK: - 更新后的CaptrueView
public struct CaptrueView: View {
    @StateObject private var recorder = ViewRecorder()
    @State private var overlayFrame: CGRect = .zero
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ZStack {
                overlayViews
                    .captureFrame(in: .global) { frame in
                        overlayFrame = frame
                        print("Overlay frame: \(frame)")
                    }
                controlButtons
            }
        }
        .frame(
            width: UIScreen.main.bounds.width - 200,
            height: UIScreen.main.bounds.height - 200
        )
    }
    
    private var overlayViews: some View {
        ZStack {
            ZStack {
                FloatView {
                    Color.blue.opacity(0.5).frame(maxWidth: 100, maxHeight: 100)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topTrailing
            )
            
            ZStack {
                Color.orange.opacity(0.5).frame(maxWidth: 100, maxHeight: 100)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomTrailing
            )
        }
        .background(Color.yellow.opacity(0.4))
    }
    
    private var controlButtons: some View {
        VStack {
            HStack {
                VStack(spacing: 8) {
                    Button(recorder.isRecording ? "录制中..." : "开始录制") {
                        startRecording()
                    }
                    .font(.caption)
                    .padding(8)
                    .background(recorder.isRecording ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .disabled(recorder.isRecording)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)
                
                VStack(spacing: 8) {
                    Button("停止录制") {
                        recorder.stopRecording()
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .disabled(!recorder.isRecording)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)
                
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
    
    private func startRecording() {
        // 获取当前窗口的根视图
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootView = window.rootViewController?.view else {
            print("无法获取根视图")
            return
        }
        
        print("开始录制，区域: \(overlayFrame)")
        recorder.startRecording(view: rootView, frame: overlayFrame)
    }
}

