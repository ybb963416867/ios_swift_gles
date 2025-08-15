import AVFoundation
//
//  YSGSSurfaceViewFromViewRender.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//
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
        // 设置视口为 FBO 的尺寸
        Gl2Utils.checkGlError()
        glViewport(0, 0, screenWidth, screenHeight)

        //        // 清除 FBO
        //        Gl2Utils.checkGlError()
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
        //        // 清除 FBO
        //        Gl2Utils.checkGlError()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        imageTextureList.forEach({ $0.onDrawFrame() })

        glDisable(GLenum(GL_BLEND))

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        if isRecording {
            captureFrame()
        }

        glkView.deleteDrawable()
        // 删除旧的 Drawable
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
            if let view = findViewByIdentifier("complexContainer", in: rootView)
            {
                //                print("找到了")
                if let fileUil = view.asImage().savePngToDocuments(
                    fileName: "aa"
                ) {
                    print("save success \(fileUil.absoluteString)")
                } else {
                    print("save failu")
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

            if let view = findViewByIdentifier("complexContainer", in: rootView)
            {

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

    /**
     * 递归查找具有指定accessibilityIdentifier的视图
     */
    private func findViewByIdentifier(_ identifier: String, in view: UIView)
        -> UIView?
    {
        // 检查当前视图
        if view.accessibilityIdentifier == identifier {
            return view
        }

        // 递归检查所有子视图
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
            //kCVPixelFormatType_32BGRA
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

    private func captureFrame() {
        guard isRecording,
                let assetWriter = self.assetWriter,
                assetWriter.status == .writing,  //
                let assetWriterInput = self.assetWriterInput,
                assetWriterInput.isReadyForMoreMediaData,  //
                let pixelBufferAdaptor = self.assetWriterPixelBufferAdaptor
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

            // 只需要翻转图像（OpenGL 坐标系是底部开始的）
            for y in 0..<height {
                for x in 0..<width {
                    let srcIndex = (y * width + x) * 4
                    let dstIndex = ((height - 1 - y) * (bytesPerRow / 4) + x) * 4

                    // 直接复制 RGBA，不需要通道转换
                    // RGBA -> BGRA
                    dstBuffer[dstIndex] = pixelData[srcIndex + 2]     // B
                    dstBuffer[dstIndex + 1] = pixelData[srcIndex + 1] // G
                    dstBuffer[dstIndex + 2] = pixelData[srcIndex]     // R
                    dstBuffer[dstIndex + 3] = pixelData[srcIndex + 3] // A
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

    func release() {
        imageTextureList.forEach { it in
            it.release()
        }
        combineTexture.release()
        displayLink?.invalidate()
    }

    deinit {
        release()
    }

}
