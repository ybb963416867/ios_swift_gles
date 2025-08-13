//
//  Render.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/18.
//

import AVFoundation
import CoreVideo
import GLKit
import SwiftUI

class Render: IRender {

    private var glkView: GLKView

    private var combineTexture: MultipleFboCombineTexture!
    private var screenWidth = GLsizei()
    private var screenHeight = GLsizei()

    private var imageTextureList: [IBaseTexture]

    // 录制相关属性
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetWriterPixelBufferAdaptor:
        AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var recordingStartTime: CMTime?
    private var frameCount: Int64 = 0
    private let recordingFrameRate: Int32 = 30  // 录制帧率
    private var videoSpeedMultiplier: Double = 1.0  // 视频播放速度倍数
    private var recordingStartTimeAbs: CFAbsoluteTime = 0  // 录制开始的绝对时间

    // OpenGL ES 相关
    private var pixelBuffer: CVPixelBuffer?
    private var recordingContext: EAGLContext?
    private var viewProvider: (() -> (AnyView, CGRect))? = nil

    func setViewProvider(_ provider: @escaping () -> (AnyView, CGRect)) {
        self.viewProvider = provider
        updateUITexture()
    }

    init(glkView: GLKView) {
        self.glkView = glkView
        combineTexture = MultipleFboCombineTexture(
            numFbo: 2,
            glkView: glkView,
            vertPath: "base_vert",
            fragPath: "base_frag"
        )

        imageTextureList = [
            ImageTexture1(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),
            ImageTexture(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),

            ImageTexture1(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),
            ImageTexture(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),

            ImageTexture1(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),
            ImageTexture(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),
        ]

        // 创建用于录制的 OpenGL ES 上下文，与现有上下文共享资源
        let sharegroup = glkView.context.sharegroup
        recordingContext = EAGLContext(
            api: glkView.context.api,
            sharegroup: sharegroup
        )
    }

    // MARK: - 录制控制方法

    // 设置视频播放速度
    func setVideoPlaybackSpeed(_ speed: Double) {
        videoSpeedMultiplier = speed
        print("视频播放速度设置为: \(speed)x")
    }

    func startRecording(outputURL: URL, playbackSpeed: Double = 1.0) -> Bool {
        guard !isRecording else { return false }

        // 设置播放速度
        videoSpeedMultiplier = playbackSpeed

        do {
            // 移除已存在的文件
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            // 创建 AVAssetWriter
            assetWriter = try AVAssetWriter(
                outputURL: outputURL,
                fileType: .mp4
            )

            // 配置视频输入设置
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(screenWidth),
                AVVideoHeightKey: Int(screenHeight),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: screenWidth * screenHeight * 4,  // 比特率
                    AVVideoProfileLevelKey:
                        AVVideoProfileLevelH264BaselineAutoLevel,
                ],
            ]

            assetWriterInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings
            )
            assetWriterInput?.expectsMediaDataInRealTime = true

            // 配置像素缓冲区适配器
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(screenWidth),
                kCVPixelBufferHeightKey as String: Int(screenHeight),
                kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            ]

            assetWriterPixelBufferAdaptor =
                AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: assetWriterInput!,
                    sourcePixelBufferAttributes: pixelBufferAttributes
                )

            // 添加输入到 writer
            if assetWriter!.canAdd(assetWriterInput!) {
                assetWriter!.add(assetWriterInput!)
            } else {
                print("无法添加视频输入到 AssetWriter")
                return false
            }

            // 开始写入会话
            assetWriter!.startWriting()
            recordingStartTime = CMTime.zero
            recordingStartTimeAbs = CFAbsoluteTimeGetCurrent()  // 记录开始录制的绝对时间
            assetWriter!.startSession(atSourceTime: recordingStartTime!)

            isRecording = true
            frameCount = 0
            return true

        } catch {
            print("开始录制失败: \(error)")
            return false
        }
    }

    func stopRecording(completion: @escaping (Bool, URL?) -> Void) {
        guard isRecording, let assetWriter = self.assetWriter else {
            completion(false, nil)
            return
        }

        isRecording = false

        assetWriterInput?.markAsFinished()

        assetWriter.finishWriting { [weak self] in
            DispatchQueue.main.async {

                let success = assetWriter.status == .completed
                let outputURL = success ? assetWriter.outputURL : nil
                // 清理资源
                self?.assetWriter = nil
                self?.assetWriterInput = nil
                self?.assetWriterPixelBufferAdaptor = nil
                self?.recordingStartTime = nil
                self?.recordingStartTimeAbs = 0
                self?.frameCount = 0
                completion(success, outputURL)
            }
        }
    }

    // MARK: - 原有方法

    func onSurfaceCreate(context: EAGLContext) {
        combineTexture.onSurfaceCreated(
            screenWidth: Int(glkView.bounds.width),
            screenHeight: Int(glkView.bounds.height)
        )
        imageTextureList.forEach { it in
            it.onSurfaceCreated()
        }
    }

    func onSurfaceChanged(width: Int, height: Int) {
        let glWidth = GLsizei(width)
        let glHeight = GLsizei(height)
        glViewport(0, 0, glWidth, glHeight)
        self.screenWidth = glWidth
        self.screenHeight = glHeight
        combineTexture.onSurfaceChanged(
            screenWidth: width,
            screenHeight: height
        )
        imageTextureList.forEach { it in
            it.onSurfaceChanged(screenWidth: width, screenHeight: height)
        }
    }

    func onDrawFrame() {
        if EAGLContext.current() == nil {
            EAGLContext.setCurrent(glkView.context)
        }

        Gl2Utils.checkGlError()
        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[0]
        )
        // 设置视口为 FBO 的尺寸
        Gl2Utils.checkGlError()
        glViewport(0, 0, screenWidth, screenHeight)

        //        // 清除 FBO
        //        Gl2Utils.checkGlError()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

        for i in 0..<imageTextureList.count {
            if i != 4 && i != 5 {
                imageTextureList[i].onDrawFrame()
            }
        }

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[1]
        )
        Gl2Utils.checkGlError()
        glViewport(0, 0, screenWidth, screenHeight)
        //        // 清除 FBO
        //        Gl2Utils.checkGlError()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        imageTextureList.forEach({ $0.onDrawFrame() })

        glDisable(GLenum(GL_BLEND))

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        // 如果正在录制，捕获当前帧
        if isRecording {
            captureFrame()
        }

        glkView.deleteDrawable()
        //        // 删除旧的 Drawable
        combineTexture.onDrawFrame(textureIdIndex: 1)
        Gl2Utils.checkGlError()
    }

    // MARK: - 帧捕获方法

    private func captureFrame() {
        guard isRecording,
            let assetWriterInput = self.assetWriterInput,
            let pixelBufferAdaptor = self.assetWriterPixelBufferAdaptor,
            assetWriterInput.isReadyForMoreMediaData
        else {
            return
        }

        // 从 FBO 读取像素数据
        let width = Int(screenWidth)
        let height = Int(screenHeight)
        let dataSize = width * height * 4
        var pixelData = [UInt8](repeating: 0, count: dataSize)

        // 绑定 FBO 并读取像素
        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[1]
        )
        glReadPixels(
            0,
            0,
            screenWidth,
            screenHeight,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            &pixelData
        )

        // 创建 CVPixelBuffer - 使用 BGRA 格式匹配 AssetWriter 的设置
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("创建 CVPixelBuffer 失败，错误码: \(status)")
            // 打印具体的错误信息
            switch status {
            case kCVReturnInvalidPixelFormat:
                print("无效的像素格式")
            case kCVReturnInvalidSize:
                print("无效的尺寸")
            case kCVReturnPixelBufferNotOpenGLCompatible:
                print("像素缓冲区与 OpenGL 不兼容")
            case kCVReturnAllocationFailed:
                print("内存分配失败")
            default:
                print("未知错误")
            }
            return
        }

        // 将像素数据复制到 CVPixelBuffer，并转换 RGBA 到 BGRA
        CVPixelBufferLockBaseAddress(
            buffer,
            CVPixelBufferLockFlags(rawValue: 0)
        )

        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let dstBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            // 翻转图像并转换 RGBA 到 BGRA（OpenGL 坐标系是底部开始的）
            for y in 0..<height {
                for x in 0..<width {
                    let srcIndex = (y * width + x) * 4
                    let dstIndex =
                        ((height - 1 - y) * (bytesPerRow / 4) + x) * 4

                    // RGBA -> BGRA 转换
                    let r = pixelData[srcIndex]
                    let g = pixelData[srcIndex + 1]
                    let b = pixelData[srcIndex + 2]
                    let a = pixelData[srcIndex + 3]

                    dstBuffer[dstIndex] = b  // B
                    dstBuffer[dstIndex + 1] = g  // G
                    dstBuffer[dstIndex + 2] = r  // R
                    dstBuffer[dstIndex + 3] = a  // A
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(
            buffer,
            CVPixelBufferLockFlags(rawValue: 0)
        )

        // 计算当前帧的时间戳（考虑播放速度）
        let presentationTime = calculatePresentationTime()

        // 添加到视频
        if pixelBufferAdaptor.append(
            buffer,
            withPresentationTime: presentationTime
        ) {
            frameCount += 1
        } else {
            print("添加帧到视频失败")
        }
    }

    // 计算演示时间戳（使用真实时间，与 captureFrame 调用频率一致）
    private func calculatePresentationTime() -> CMTime {
        // 使用真实经过的时间作为时间戳
        let currentTimeAbs = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTimeAbs - recordingStartTimeAbs

        // 应用速度倍数（如果需要）
        let adjustedTime = elapsedTime * videoSpeedMultiplier

        return CMTime(seconds: adjustedTime, preferredTimescale: 600)  // 使用高精度时间基准

        // 备选方法：如果不需要速度控制，直接使用真实时间
        // return CMTime(seconds: elapsedTime, preferredTimescale: 600)
    }

    // MARK: - 原有方法继续

    func loadTexture() {
        let moduleBundle = Bundle(for: Render.self)
        guard
            let spriteImage = UIImage(
                named: "yunshen.jpg",
                in: moduleBundle,
                compatibleWith: nil
            )?.cgImage
        else {
            fatalError("无法加载子模块的图片")
        }
        let result = imageTextureList[0].getTextureInfo().generateBitmapTexture(
            cgImage: spriteImage
        )
        imageTextureList[0].updateTextureInfo(
            textureInfo: result,
            isRecoverCord: false,
            iTextureVisibility: ITextureVisibility.VISIBLE
        )

        let result1 = imageTextureList[1].getTextureInfo()
            .generateBitmapTexture(cgImage: spriteImage)
        imageTextureList[1].updateTextureInfo(
            textureInfo: result1,
            isRecoverCord: false,
            iTextureVisibility: ITextureVisibility.VISIBLE
        )

        guard
            let spriteImage1 = UIImage(
                named: "cc.jpg",
                in: moduleBundle,
                compatibleWith: nil
            )?.cgImage
        else {
            fatalError("无法加载子模块的图片")
        }

        let result2 = imageTextureList[2].getTextureInfo()
            .generateBitmapTexture(cgImage: spriteImage1)
        imageTextureList[2].updateTextureInfo(
            textureInfo: result2,
            isRecoverCord: false,
            iTextureVisibility: ITextureVisibility.VISIBLE
        )

        let result3 = imageTextureList[3].getTextureInfo()
            .generateBitmapTexture(cgImage: spriteImage1)
        imageTextureList[3].updateTextureInfo(
            textureInfo: result3,
            isRecoverCord: false,
            iTextureVisibility: ITextureVisibility.VISIBLE
        )

        glkView.setNeedsDisplay()

    }

    func updateUITexture() {

        guard let provider = viewProvider else { return }
        let (uiView, rect) = provider()

        if let viewImage = renderSwiftUIViewToImage(uiView, rect: rect),
            let vImage = viewImage.cgImage
        {

            let result4 = imageTextureList[4].getTextureInfo()
                .generateBitmapTexture(cgImage: vImage)
            imageTextureList[4].updateTextureInfo(
                textureInfo: result4,
                isRecoverCord: false,
                iTextureVisibility: .VISIBLE
            )
            let result5 = imageTextureList[5].getTextureInfo()
                .generateBitmapTexture(cgImage: vImage)
            imageTextureList[5].updateTextureInfo(
                textureInfo: result5,
                isRecoverCord: false,
                iTextureVisibility: .VISIBLE
            )

            print("screenWidth = \(screenWidth) screenHeight = \(screenHeight)")

            glkView.setNeedsDisplay()

            //                        let dateFormatter = DateFormatter()
            //                        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            //                        let timestamp = dateFormatter.string(from: Date())
            //            if let url = vImage.savaPngToDocuments(fileName: timestamp) {
            //                print("url = \(url.path())")
            //            }
            //            _ = render.saveImageAsPNG(viewImage, to: timestamp)
        }

    }

    func test() {
        let coordinateRegion = CoordinateRegion().generateCoordinateRegion(
            left: 150,
            top: 0,
            width: 200,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[0].updateTexCord(coordinateRegion: coordinateRegion)

        let coordinateRegion1 = CoordinateRegion().generateCoordinateRegion(
            left: 150,
            top: 0,
            width: 200,
            height: 200
        )
        imageTextureList[1].updateTexCord(coordinateRegion: coordinateRegion1)

        let coordinateRegion2 = CoordinateRegion().generateCoordinateRegion(
            left: 150,
            top: 200,
            width: 200,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[2].updateTexCord(coordinateRegion: coordinateRegion2)

        let coordinateRegion3 = CoordinateRegion().generateCoordinateRegion(
            left: 150,
            top: 200,
            width: 200,
            height: 200
        )
        imageTextureList[3].updateTexCord(coordinateRegion: coordinateRegion3)

        glkView.setNeedsDisplay()
    }

    func test2() {
        let coordinateRegion = CoordinateRegion().generateCoordinateRegion(
            left: 200,
            top: 100,
            width: 100,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[0].updateTexCord(coordinateRegion: coordinateRegion)

        let coordinateRegion1 = CoordinateRegion().generateCoordinateRegion(
            left: 200,
            top: 100,
            width: 100,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[1].updateTexCord(coordinateRegion: coordinateRegion1)

        let coordinateRegion2 = CoordinateRegion().generateCoordinateRegion(
            left: 200,
            top: 300,
            width: 100,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[2].updateTexCord(coordinateRegion: coordinateRegion2)

        let coordinateRegion3 = CoordinateRegion().generateCoordinateRegion(
            left: 200,
            top: 300,
            width: 100,
            height: 200
        )
        //        print("region = \(coordinateRegion) \n")
        imageTextureList[3].updateTexCord(coordinateRegion: coordinateRegion3)

        glkView.setNeedsDisplay()
    }

    func textUIImage() {
        let coordinateRegion4 = CoordinateRegion().generateCoordinateRegion(
            left: 300,
            top: 300,
            width: 100,
            height: 200
        )
        imageTextureList[4].updateTexCord(coordinateRegion: coordinateRegion4)

        let coordinateRegion5 = CoordinateRegion().generateCoordinateRegion(
            left: 400,
            top: 300,
            width: 100,
            height: 200
        )
        imageTextureList[5].updateTexCord(coordinateRegion: coordinateRegion5)

        glkView.setNeedsDisplay()
    }

    func release() {
        // 如果正在录制，先停止录制
        if isRecording {
            stopRecording { _, _ in }
        }

        imageTextureList.forEach { it in
            it.release()
        }
        combineTexture.release()
    }
}

extension Render {
    public func renderSwiftUIViewToImage<V: View>(_ view: V, rect: CGRect)
        -> UIImage?
    {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .clear

        // 固定 hostingController 的大小
        hostingController.view.frame = rect

        // 固定容器大小
        let container = UIView(frame: rect)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(
                equalTo: container.topAnchor
            ),
            hostingController.view.bottomAnchor.constraint(
                equalTo: container.bottomAnchor
            ),
            hostingController.view.leadingAnchor.constraint(
                equalTo: container.leadingAnchor
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            ),
            container.widthAnchor.constraint(equalToConstant: rect.size.width),
            container.heightAnchor.constraint(
                equalToConstant: rect.size.height
            ),
        ])

        container.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { _ in
            container.drawHierarchy(
                in: CGRect(origin: .zero, size: rect.size),
                afterScreenUpdates: true
            )
        }
    }

    public func saveImageAsPNG(_ image: UIImage, to fileName: String) -> URL? {
        // 1. 转成 PNG Data
        guard let pngData = image.pngData() else {
            print("转换 PNG 失败")
            return nil
        }

        // 2. 生成文件路径（保存到 Documents 目录）
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)
            .appendingPathExtension("png")

        do {
            // 3. 写入文件
            try pngData.write(to: fileURL)
            print("保存成功: \(fileURL)")
            return fileURL
        } catch {
            print("保存失败: \(error)")
            return nil
        }
    }
}
