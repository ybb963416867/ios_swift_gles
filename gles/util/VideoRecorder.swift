import AVFoundation
import GLKit

// MARK: - 视频录制器协议
protocol VideoRecorderDelegate: AnyObject {
    func videoRecorderDidStartRecording(_ recorder: VideoRecorder)
    func videoRecorderDidStopRecording(_ recorder: VideoRecorder, success: Bool, outputURL: URL?)
    func videoRecorderDidCaptureFrame(_ recorder: VideoRecorder, frameCount: Int64)
}

// MARK: - 独立的视频录制器类
class VideoRecorder {
    
    // MARK: - Properties
    
    weak var delegate: VideoRecorderDelegate?
    
    // 录制状态
    private(set) var isRecording = false
    private(set) var frameCount: Int64 = 0
    
    // 录制配置
    private let recordingFrameRate: Int32
    private let minCaptureInterval: CFAbsoluteTime
    private var videoSpeedMultiplier: Double = 1.0
    
    // AVFoundation 组件
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetWriterPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // 时间管理
    private var recordingStartTime: CMTime?
    private var recordingStartTimeAbs: CFAbsoluteTime = 0
    private var lastCaptureTime: CFAbsoluteTime = 0
    private var lastPresentationTime: CMTime = .zero
    
    // 性能优化
    private let recordingQueue = DispatchQueue(label: "com.videorecorder.queue", qos: .userInitiated)
    private var pixelBufferPool: CVPixelBufferPool?
    private var reusablePixelData: UnsafeMutablePointer<UInt8>?
    private var pixelDataSize: Int = 0
    
    // 帧缓冲
    private var pendingFrames = [PendingFrame]()
    private let pendingFramesLock = NSLock()
    private var isProcessingFrames = false
    
    // 视频尺寸
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    
    private var firstValidFrameCaptured: Bool = false
    
    var isUserRealRate: Bool = true
    
    // MARK: - Types
    
    private struct PendingFrame {
        let pixelData: Data
        let presentationTime: CMTime
        let width: Int
        let height: Int
    }
    
    // MARK: - Initialization
    
    init(frameRate: Int32 = 30) {
        self.recordingFrameRate = frameRate
        self.minCaptureInterval = 1.0 / Double(frameRate)
    }
    
    deinit {
        cleanupResources()
    }
    
    // MARK: - Public Methods
    
    /// 配置录制尺寸
    func configureSize(width: Int, height: Int) {
        guard !isRecording else {
            print("无法在录制中更改尺寸")
            return
        }
        
        videoWidth = width
        videoHeight = height
        
        // 更新像素数据缓冲区
        pixelDataSize = width * height * 4
        reusablePixelData?.deallocate()
        reusablePixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelDataSize)
    }
    
    /// 开始录制
    func startRecording(outputURL: URL, playbackSpeed: Double = 1.0) -> Bool {
        guard !isRecording else {
            print("已经在录制中")
            return false
        }
        
        guard videoWidth > 0 && videoHeight > 0 else {
            print("请先配置视频尺寸")
            return false
        }
        
        videoSpeedMultiplier = playbackSpeed
        
        do {
            // 移除已存在的文件
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            // 创建 AVAssetWriter
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            // 配置视频设置 - 修复1: 使用正确的视频编码设置
            let videoSettings = if isUserRealRate { createRealVideoSettings() } else { createVideoSettings() }
            assetWriterInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings
            )
            assetWriterInput?.expectsMediaDataInRealTime = true // 修复2: 改为 true
            
            // 创建像素缓冲适配器
            let pixelBufferAttributes = createPixelBufferAttributes()
            assetWriterPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
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
            
            // 开始写入
            if !assetWriter!.startWriting() {
                print("无法开始写入，错误: \(assetWriter!.error?.localizedDescription ?? "未知错误")")
                return false
            }
            
            // 开始会话
            assetWriter!.startSession(atSourceTime: .zero)
            
            // 更新状态
            isRecording = true
            firstValidFrameCaptured = false
            frameCount = 0
            lastCaptureTime = 0
            
            // 启动帧处理
            startFrameProcessing()
            
            // 通知代理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.videoRecorderDidStartRecording(self)
            }
            
            print("录制开始成功")
            return true
            
        } catch {
            print("开始录制失败: \(error)")
            return false
        }
    }
    
    /// 停止录制
    func stopRecording(completion: @escaping (Bool, URL?) -> Void) {
        guard isRecording, let assetWriter = self.assetWriter else {
            completion(false, nil)
            return
        }
        
        isRecording = false
        firstValidFrameCaptured = false
        isProcessingFrames = false
        
        print("正在停止录制，处理剩余帧...")
        
        // 在后台队列处理剩余帧并完成写入
        recordingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 处理剩余的帧
            self.processPendingFrames()
            
            // 等待输入准备好
            while !(self.assetWriterInput?.isReadyForMoreMediaData ?? false) {
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            // 标记输入完成
            self.assetWriterInput?.markAsFinished()
            
            // 完成写入
            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    let success = assetWriter.status == .completed
                    let outputURL = success ? assetWriter.outputURL : nil
                    
                    if !success {
                        print("录制失败，状态: \(assetWriter.status.rawValue)")
                        if let error = assetWriter.error {
                            print("错误信息: \(error)")
                        }
                    } else {
                        print("录制成功完成，共 \(self.frameCount) 帧")
                    }
                    
                    // 清理资源
                    self.cleanupRecordingResources()
                    
                    // 通知代理
                    self.delegate?.videoRecorderDidStopRecording(self, success: success, outputURL: outputURL)
                    
                    // 调用完成回调
                    completion(success, outputURL)
                }
            }
        }
    }
    
    /// 捕获一帧（从 OpenGL FBO）
    func captureFrame(from fbo: GLuint) {
        guard isRecording else { return }
        let currentTime = CFAbsoluteTimeGetCurrent()
        if !isUserRealRate {
            // 检查帧率限制
            if currentTime - lastCaptureTime < minCaptureInterval {
                return
            }
        }

        lastCaptureTime = currentTime
        
        guard let pixelData = reusablePixelData else { return }
        
        // 绑定 FBO 并读取像素
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
        
        glReadPixels(
            0, 0,
            GLsizei(videoWidth), GLsizei(videoHeight),
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            pixelData
        )
        let presentationTime: CMTime
        if !firstValidFrameCaptured {
            presentationTime = .zero
            // 初始化时间
            recordingStartTimeAbs = CFAbsoluteTimeGetCurrent()
            lastPresentationTime = .zero
            recordingStartTime = .zero
            firstValidFrameCaptured = true
        }  else {
            presentationTime = if isUserRealRate { calculatePresentationTimeReal() } else { calculatePresentationTime() }
        }
        // 创建帧数据
        let frameData = Data(bytes: pixelData, count: pixelDataSize)
      
        
        let pendingFrame = PendingFrame(
            pixelData: frameData,
            presentationTime: presentationTime,
            width: videoWidth,
            height: videoHeight
        )
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
        // 添加到待处理队列
        pendingFramesLock.lock()
        pendingFrames.append(pendingFrame)
        pendingFramesLock.unlock()
    }
    
    /// 捕获一帧（从像素数据）
    func captureFrame(pixelData: Data, width: Int, height: Int) {
        guard isRecording else { return }
        
        // 检查帧率限制
        let currentTime = CFAbsoluteTimeGetCurrent()
        if !isUserRealRate {
            // 检查帧率限制
            if currentTime - lastCaptureTime < minCaptureInterval {
                return
            }
        }
        lastCaptureTime = currentTime
        
        let presentationTime = if isUserRealRate { calculatePresentationTimeReal() } else { calculatePresentationTime() }
        
        let pendingFrame = PendingFrame(
            pixelData: pixelData,
            presentationTime: presentationTime,
            width: width,
            height: height
        )
        
        // 添加到待处理队列
        pendingFramesLock.lock()
        pendingFrames.append(pendingFrame)
        pendingFramesLock.unlock()
    }
    
    // MARK: - Private Methods
    
    private func createVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: NSNumber(value: videoWidth * videoHeight * 10), // 提高比特率
                AVVideoProfileLevelKey: AVVideoProfileLevelH264High41, // 使用更高的配置
                AVVideoExpectedSourceFrameRateKey: NSNumber(value: recordingFrameRate),
                AVVideoMaxKeyFrameIntervalKey: NSNumber(value: recordingFrameRate),
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
    }
    
    private func createRealVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: NSNumber(value: videoWidth * videoHeight * 10), // 提高比特率
                AVVideoProfileLevelKey: AVVideoProfileLevelH264High41, // 使用更高的配置
//                AVVideoProfileLevelKey:
//                    AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
    }
    
    private func createPixelBufferAttributes() -> [String: Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
    }
    
    private func startFrameProcessing() {
        isProcessingFrames = true
        recordingQueue.async { [weak self] in
            while self?.isProcessingFrames == true {
                self?.processPendingFrames()
                Thread.sleep(forTimeInterval: 0.01) // 更频繁地处理
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
              let pixelBufferAdaptor = self.assetWriterPixelBufferAdaptor else {
            return
        }
        
        // 等待输入准备好
        while !assetWriterInput.isReadyForMoreMediaData && isProcessingFrames {
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        guard assetWriterInput.isReadyForMoreMediaData else { return }
        
        autoreleasepool {
            // 创建像素缓冲区 - 修复4: 确保从池中获取
            var pixelBuffer: CVPixelBuffer?
            let pool = pixelBufferAdaptor.pixelBufferPool
            
            if let pool = pool {
                let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
                if status != kCVReturnSuccess {
                    print("从池创建像素缓冲区失败: \(status)")
                }
            }
            
            // 如果池中没有可用的，创建新的
            if pixelBuffer == nil {
                let attributes = createPixelBufferAttributes()
                let status = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    frame.width,
                    frame.height,
                    kCVPixelFormatType_32BGRA,
                    attributes as CFDictionary,
                    &pixelBuffer
                )
                
                if status != kCVReturnSuccess {
                    print("创建像素缓冲区失败: \(status)")
                    return
                }
            }
            
            guard let buffer = pixelBuffer else {
                print("无法创建像素缓冲区")
                return
            }
            
            // 转换并复制像素数据
            CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                let dstBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
                
                frame.pixelData.withUnsafeBytes { srcBytes in
                    if let srcBuffer = srcBytes.bindMemory(to: UInt8.self).baseAddress {
                        convertRGBAToFlippedBGRA(
                            src: srcBuffer,
                            dst: dstBuffer,
                            width: frame.width,
                            height: frame.height,
                            dstBytesPerRow: bytesPerRow
                        )
                    }
                }
            }
            
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            
            // 添加到视频 - 修复5: 确保时间戳正确
            if pixelBufferAdaptor.append(buffer, withPresentationTime: frame.presentationTime) {
                frameCount += 1
                lastPresentationTime = frame.presentationTime
                
                // 通知代理（在主线程）
                if frameCount % 30 == 0 { // 每30帧通知一次，减少开销
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.delegate?.videoRecorderDidCaptureFrame(self, frameCount: self.frameCount)
                    }
                }
            } else {
                print("添加帧失败，时间戳: \(frame.presentationTime.seconds)")
            }
        }
    }
    
    private func convertRGBAToFlippedBGRA(
        src: UnsafePointer<UInt8>,
        dst: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        dstBytesPerRow: Int
    ) {
        let srcBytesPerRow = width * 4
        for y in 0..<height {
            let flippedY = height - 1 - y
            let srcRowStart = y * srcBytesPerRow
            let dstRowStart = flippedY * dstBytesPerRow
            
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
        let frameNumber = frameCount
        let frameDuration = 1.0 / Double(recordingFrameRate)
        let seconds = Double(frameNumber) * frameDuration * videoSpeedMultiplier
        return CMTime(seconds: seconds, preferredTimescale: 600)
    }
    
    private func calculatePresentationTimeReal() -> CMTime {
        let currentTimeAbs = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTimeAbs - recordingStartTimeAbs
        let adjustedTime = elapsedTime * videoSpeedMultiplier
        return CMTime(seconds: adjustedTime, preferredTimescale: 600)
    }
    
    private func cleanupRecordingResources() {
        isProcessingFrames = false
        assetWriter = nil
        assetWriterInput = nil
        assetWriterPixelBufferAdaptor = nil
        recordingStartTime = nil
        recordingStartTimeAbs = 0
        frameCount = 0
        pixelBufferPool = nil
        lastPresentationTime = .zero
        
        pendingFramesLock.lock()
        pendingFrames.removeAll()
        pendingFramesLock.unlock()
    }
    
    private func cleanupResources() {
        cleanupRecordingResources()
        reusablePixelData?.deallocate()
        reusablePixelData = nil
    }
}
