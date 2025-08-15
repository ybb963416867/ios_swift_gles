import AVFoundation
import GLKit
import SwiftUI

class RenderFromViewTexture: IRender {

    private var glkView: GLKView
    private var displayLink: CADisplayLink?

    private var combineTexture: MultipleFboCombineTexture!
    private var screenWidth = GLsizei()
    private var screenHeight = GLsizei()

    private var imageTextureList: [IBaseTexture]
    private var rect: CGRect = .zero
    private var frameInterval: Int = 15
    private var rootView: UIView? = nil
    private var isLoadTexture = false

    // 录制相关属性
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetWriterPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var recordingStartTime: CMTime?
    private var frameCount: Int64 = 0
    private let recordingFrameRate: Int32 = 30
    private var videoSpeedMultiplier: Double = 1.0
    private var recordingStartTimeAbs: CFAbsoluteTime = 0
    
    // OpenGL ES 相关
    private var recordingContext: EAGLContext?
    
    // 性能优化相关
    private let recordingQueue = DispatchQueue(label: "com.recording.queue", qos: .userInitiated)
    private var pixelBufferPool: CVPixelBufferPool?
    private var reusablePixelData: UnsafeMutablePointer<UInt8>?
    private var pixelDataSize: Int = 0
    private var pendingFrames = [PendingFrame]()
    private let pendingFramesLock = NSLock()
    private var lastCaptureTime: CFAbsoluteTime = 0
    private let minCaptureInterval: CFAbsoluteTime = 1.0 / 30.0 // 30 FPS max
    
    // 用于存储待处理的帧数据
    private struct PendingFrame {
        let pixelData: Data
        let presentationTime: CMTime
        let width: Int
        let height: Int
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
            ImageTexture(
                glkView: glkView,
                vertPath: "base_vert",
                fragPath: "base_frag"
            ),
        ]

        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateTexture)
        )
        displayLink?.preferredFramesPerSecond = frameInterval
        displayLink?.isPaused = true
        displayLink?.add(to: .main, forMode: .default)

        // 创建用于录制的 OpenGL ES 上下文，与现有上下文共享资源
        let sharegroup = glkView.context.sharegroup
        recordingContext = EAGLContext(
            api: glkView.context.api,
            sharegroup: sharegroup
        )
    }

    func setRect(_ viewRect: CGRect) {
        self.rect = viewRect
        updateViewTexture()
    }

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
        
        // 更新像素数据缓冲区大小
        pixelDataSize = width * height * 4
        reusablePixelData?.deallocate()
        reusablePixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelDataSize)
        
        combineTexture.onSurfaceChanged(
            screenWidth: width,
            screenHeight: height
        )
        imageTextureList.forEach { it in
            it.onSurfaceChanged(screenWidth: width, screenHeight: height)
        }
    }

    func onDrawFrame() {
        if !isLoadTexture {
            return
        }
        if EAGLContext.current() == nil {
            EAGLContext.setCurrent(glkView.context)
        }

        Gl2Utils.checkGlError()
        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[0]
        )
        Gl2Utils.checkGlError()
        glViewport(0, 0, screenWidth, screenHeight)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

        for i in 0..<imageTextureList.count {
            if i != 2 {
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
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        imageTextureList.forEach({ $0.onDrawFrame() })

        glDisable(GLenum(GL_BLEND))

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        // 优化：只在需要时捕获帧，并使用时间限制
        if isRecording {
            let currentTime = CFAbsoluteTimeGetCurrent()
            if currentTime - lastCaptureTime >= minCaptureInterval {
                captureFrameAsync()
                lastCaptureTime = currentTime
            }
        }

        glkView.deleteDrawable()
        combineTexture.onDrawFrame(textureIdIndex: 1)
        Gl2Utils.checkGlError()
    }

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

        guard
            let spriteImage1 = UIImage(
                named: "cc.jpg",
                in: moduleBundle,
                compatibleWith: nil
            )?.cgImage
        else {
            fatalError("无法加载子模块的图片")
        }

        let result1 = imageTextureList[1].getTextureInfo()
            .generateBitmapTexture(
                cgImage: spriteImage1
            )

        imageTextureList[1].updateTextureInfo(
            textureInfo: result1,
            isRecoverCord: false,
            iTextureVisibility: ITextureVisibility.VISIBLE
        )

        glkView.setNeedsDisplay()
    }

    func test() {
        if let rootView = rootView {
            if let view = findViewByIdentifier("complexContainer", in: rootView) {
                if let fileUrl = view.asImage().savePngToDocuments(
                    fileName: "aa"
                ) {
                    print("save success \(fileUrl.absoluteString)")
                } else {
                    print("save fail")
                }
            } else {
                print("没有找到")
            }
        }
    }

    func updateViewTexture() {
        isLoadTexture = true

        if self.rootView == nil {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first
                    as? UIWindowScene,
                let window = windowScene.windows.first,
                let rootView = window.rootViewController?.view
            else {
                return
            }
            self.rootView = rootView
        }

        if let rootView = self.rootView {
            if let view = findViewByIdentifier("complexContainer", in: rootView) {
                let result = imageTextureList[2].getTextureInfo()
                    .generaTextureFromView(view)

                imageTextureList[2].updateTextureInfo(
                    textureInfo: result,
                    isRecoverCord: false,
                    iTextureVisibility: ITextureVisibility.VISIBLE
                )

                glkView.setNeedsDisplay()
            }
        }
    }

    func start() {
        displayLink?.isPaused = false
    }

    func stop() {
        displayLink?.isPaused = true
    }

    func updateViewTexturePostion() {
        imageTextureList[2].updateTexCord(
            coordinateRegion: CoordinateRegion().generateCoordinateRegion(
                left: 10,
                top: 10,
                width: imageTextureList[2].getScreenWidth() - 20,
                height: imageTextureList[2].getScreenHeight() - 20
            )
        )
        glkView.setNeedsDisplay()
    }

    private func findViewByIdentifier(_ identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier {
            return view
        }

        for subview in view.subviews {
            if let found = findViewByIdentifier(identifier, in: subview) {
                return found
            }
        }

        return nil
    }

    @objc func updateTexture() {
        updateViewTexture()
    }

    // MARK: - 优化后的录制功能

    func startRecording(outputURL: URL, playbackSpeed: Double = 1.0) -> Bool {
        guard !isRecording else { return false }

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
                    AVVideoAverageBitRateKey: screenWidth * screenHeight * 4,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                    AVVideoExpectedSourceFrameRateKey: recordingFrameRate,
                    AVVideoMaxKeyFrameIntervalKey: recordingFrameRate * 2,
                ],
            ]

            assetWriterInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings
            )
            assetWriterInput?.expectsMediaDataInRealTime = false // 改为false以优化性能

            // 创建像素缓冲池
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(screenWidth),
                kCVPixelBufferHeightKey as String: Int(screenHeight),
                kCVPixelBufferOpenGLESCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]

            assetWriterPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput!,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )

            // 获取像素缓冲池
            pixelBufferPool = assetWriterPixelBufferAdaptor?.pixelBufferPool

            if assetWriter!.canAdd(assetWriterInput!) {
                assetWriter!.add(assetWriterInput!)
            } else {
                print("无法添加视频输入到 AssetWriter")
                return false
            }

            assetWriter!.startWriting()
            recordingStartTime = CMTime.zero
            recordingStartTimeAbs = CFAbsoluteTimeGetCurrent()
            assetWriter!.startSession(atSourceTime: recordingStartTime!)
            isRecording = true
            frameCount = 0
            lastCaptureTime = 0
            
            // 启动异步处理线程
            startFrameProcessing()
            
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

        // 等待所有待处理的帧完成
        recordingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 处理剩余的帧
            self.processPendingFrames()
            
            // 标记输入完成
            self.assetWriterInput?.markAsFinished()

            // 完成写入
            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    let success = assetWriter.status == .completed
                    let outputURL = success ? assetWriter.outputURL : nil
                    
                    // 清理资源
                    self.cleanupRecordingResources()
                    
                    completion(success, outputURL)
                }
            }
        }
    }

    private func captureFrameAsync() {
        guard isRecording,
              let pixelData = reusablePixelData else {
            return
        }

        let width = Int(screenWidth)
        let height = Int(screenHeight)
        
        // 绑定 FBO 并读取像素
        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[1]
        )
        
        // 直接读取到预分配的缓冲区
        glReadPixels(
            0,
            0,
            screenWidth,
            screenHeight,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            pixelData
        )
        
        // 创建数据副本并计算时间戳
        let frameData = Data(bytes: pixelData, count: pixelDataSize)
        let presentationTime = calculatePresentationTime()
        
        // 创建待处理帧
        let pendingFrame = PendingFrame(
            pixelData: frameData,
            presentationTime: presentationTime,
            width: width,
            height: height
        )
        
        // 添加到待处理队列
        pendingFramesLock.lock()
        pendingFrames.append(pendingFrame)
        pendingFramesLock.unlock()
    }

    private func startFrameProcessing() {
        recordingQueue.async { [weak self] in
            while self?.isRecording == true {
                self?.processPendingFrames()
                Thread.sleep(forTimeInterval: 0.016) // ~60 FPS processing
            }
        }
    }

    private func processPendingFrames() {
        pendingFramesLock.lock()
        let framesToProcess = pendingFrames
        pendingFrames.removeAll()
        pendingFramesLock.unlock()
        
        for frame in framesToProcess {
            processFrame(frame)
        }
    }

    private func processFrame(_ frame: PendingFrame) {
        guard let assetWriterInput = self.assetWriterInput,
              assetWriterInput.isReadyForMoreMediaData,
              let pixelBufferAdaptor = self.assetWriterPixelBufferAdaptor else {
            return
        }

        autoreleasepool {
            // 从池中获取像素缓冲区
            var pixelBuffer: CVPixelBuffer?
            
            if let pool = pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            }
            
            // 如果池中没有可用的，创建新的
            if pixelBuffer == nil {
                let pixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: frame.width,
                    kCVPixelBufferHeightKey as String: frame.height,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                ]
                
                CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    frame.width,
                    frame.height,
                    kCVPixelFormatType_32BGRA,
                    pixelBufferAttributes as CFDictionary,
                    &pixelBuffer
                )
            }
            
            guard let buffer = pixelBuffer else { return }
            
            // 锁定像素缓冲区并复制数据
            CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                let dstBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
                
                frame.pixelData.withUnsafeBytes { srcBytes in
                    let srcBuffer = srcBytes.bindMemory(to: UInt8.self).baseAddress!
                    
                    // 使用 SIMD 优化的像素转换
                    convertRGBAToFlippedBGRA(
                        src: srcBuffer,
                        dst: dstBuffer,
                        width: frame.width,
                        height: frame.height,
                        dstBytesPerRow: bytesPerRow
                    )
                }
            }
            
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            
            // 添加到视频
            if pixelBufferAdaptor.append(buffer, withPresentationTime: frame.presentationTime) {
                frameCount += 1
            }
        }
    }

    // SIMD 优化的像素转换函数
    private func convertRGBAToFlippedBGRA(
        src: UnsafePointer<UInt8>,
        dst: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        dstBytesPerRow: Int
    ) {
        let srcBytesPerRow = width * 4
        
        // 使用并发队列处理多行
        DispatchQueue.concurrentPerform(iterations: height) { y in
            let flippedY = height - 1 - y
            let srcRowStart = y * srcBytesPerRow
            let dstRowStart = flippedY * dstBytesPerRow
            
            // 处理每一行的像素
            for x in 0..<width {
                let srcIndex = srcRowStart + x * 4
                let dstIndex = dstRowStart + x * 4
                
                // RGBA -> BGRA
                dst[dstIndex] = src[srcIndex + 2]     // B
                dst[dstIndex + 1] = src[srcIndex + 1] // G
                dst[dstIndex + 2] = src[srcIndex]     // R
                dst[dstIndex + 3] = src[srcIndex + 3] // A
            }
        }
    }

    private func calculatePresentationTime() -> CMTime {
        let currentTimeAbs = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTimeAbs - recordingStartTimeAbs
        let adjustedTime = elapsedTime * videoSpeedMultiplier
        return CMTime(seconds: adjustedTime, preferredTimescale: 600)
    }

    private func cleanupRecordingResources() {
        assetWriter = nil
        assetWriterInput = nil
        assetWriterPixelBufferAdaptor = nil
        recordingStartTime = nil
        recordingStartTimeAbs = 0
        frameCount = 0
        pixelBufferPool = nil
        
        pendingFramesLock.lock()
        pendingFrames.removeAll()
        pendingFramesLock.unlock()
    }

    func release() {
        imageTextureList.forEach { it in
            it.release()
        }
        combineTexture.release()
        displayLink?.invalidate()
        
        // 释放像素数据缓冲区
        reusablePixelData?.deallocate()
        reusablePixelData = nil
    }

    deinit {
        release()
    }
}
