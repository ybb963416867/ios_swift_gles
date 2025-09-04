import AVFoundation
import GLKit
import SwiftUI

// MARK: - 截图完成回调
protocol ScreenshotDelegate: AnyObject {
    func didCaptureScreenshot(_ image: UIImage?, fileURL: URL?)
}

// MARK: - 重构后的渲染类（添加截图功能）
class RenderFromViewTexture: IRender {

    // MARK: - Properties

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

    // 视频录制器
    private var videoRecorder: VideoRecorder
    private var recordingContext: EAGLContext?

    // 截图相关
    private let screenshotManager = ScreenshotManager.shared
    weak var screenshotDelegate: ScreenshotDelegate?

    // MARK: - Initialization

    init(glkView: GLKView) {
        self.glkView = glkView
        self.videoRecorder = VideoRecorder(frameRate: 30)

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

        // 创建用于录制的 OpenGL ES 上下文
        let sharegroup = glkView.context.sharegroup
        recordingContext = EAGLContext(
            api: glkView.context.api,
            sharegroup: sharegroup
        )

        // 设置录制器代理
        videoRecorder.delegate = self
    }

    deinit {
        release()
    }

    // MARK: - IRender Implementation

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

        // 配置录制器尺寸
        videoRecorder.configureSize(width: width, height: height)

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

        // 渲染到第一个 FBO
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

        // 渲染到第二个 FBO（用于录制和截图）
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

        // 如果正在录制，捕获帧
        if videoRecorder.isRecording {
            videoRecorder.captureFrame(
                from: combineTexture.getFboFrameBuffer()[1]
            )
        }

        glkView.deleteDrawable()
        combineTexture.onDrawFrame(textureIdIndex: 1)
        Gl2Utils.checkGlError()
    }

    func onScreenShot() {
        // 确保上下文
        if EAGLContext.current() == nil {
            EAGLContext.setCurrent(glkView.context)
        }

        // 如果有 MSAA，请先 resolve 到一个非 MSAA 的中间 FBO/纹理再从那里读
        // resolveMSAAFBOIfNeeded()

        // 绑定到最终合成的 FBO（你的代码里最终在 FBO[1] 上做了合成）
        glBindFramebuffer(
            GLenum(GL_FRAMEBUFFER),
            combineTexture.getFboFrameBuffer()[0]
        )

        // 保守：对齐为 1，避免行对齐带来的错行
        glPixelStorei(GLenum(GL_PACK_ALIGNMENT), 1)

        // 等 GPU 完成渲染
        glFinish()

        let width = Int(screenWidth)
        let height = Int(screenHeight)
        guard width > 0, height > 0 else {
            print("invalid size \(width)x\(height)")
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            return
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let size = bytesPerRow * height

        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { pixelData.deallocate() }

        // 最稳：按 RGBA 读
        glReadPixels(
            0,
            0,
            GLsizei(width),
            GLsizei(height),
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            pixelData
        )

        // 垂直翻转一份
        //        let flipped = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        //        defer { flipped.deallocate() }
        //        for y in 0..<height {
        //            let src = pixelData.advanced(by: y * bytesPerRow)
        //            let dst = flipped.advanced(by: (height - 1 - y) * bytesPerRow)
        //            memcpy(dst, src, bytesPerRow)
        //        }

        // 垂直翻转 + 把 Alpha 补成不透明（255）
        let flipped = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { flipped.deallocate() }
        for y in 0..<height {
            let srcRow = pixelData.advanced(by: y * bytesPerRow)
            let dstRow = flipped.advanced(by: (height - 1 - y) * bytesPerRow)

            var x = 0
            while x < bytesPerRow {
                // RGBA 顺序（byteOrder32Big + premultipliedLast）
                dstRow[x + 0] = srcRow[x + 0]  // R
                dstRow[x + 1] = srcRow[x + 1]  // G
                dstRow[x + 2] = srcRow[x + 2]  // B
                dstRow[x + 3] = 255  // A 固定为不透明
                x += 4
            }
        }

        // 用与 RGBA 匹配的 bitmapInfo：32 Big Endian + premultipliedLast
        //（在 Swift 中使用 .byteOrder32Big + .premultipliedLast 与 RGBA 内存布局对应）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo =
            CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue

        guard
            let ctx = CGContext(
                data: flipped,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else {
            print("无法创建 CGContext")
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            return
        }

        guard let cgImage = ctx.makeImage() else {
            print("无法创建 CGImage")
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            return
        }

        // 解绑
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        //        if let fileUrl = UIImage(cgImage: cgImage).saveToDocuments(fileUrl: FileUtil.getPngDocumentsFile("c")) {
        //            print("fileUrl = \(fileUrl.absoluteString)")
        //        } else {
        //            print("fileUrl = nil")
        //        }
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
        if let view = ViewRegistry.shared.find("complexContainer") {
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

        if let view = ViewRegistry.shared.find("complexContainer") {
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

    func release() {
        imageTextureList.forEach { it in
            it.release()
        }
        combineTexture.release()
        displayLink?.invalidate()
    }

    // MARK: - Screenshot Methods

    /// 捕获截图
    func captureScreenshot(
        saveToFile: Bool = true,
        saveToPhotoLibrary: Bool = false
    ) -> UIImage? {
        // 确保 OpenGL 上下文正确
        if EAGLContext.current() == nil {
            EAGLContext.setCurrent(glkView.context)
        }

        // 从 FBO 捕获截图
        let image = screenshotManager.captureScreenshot(
            from: combineTexture.getFboFrameBuffer()[1],
            width: Int(screenWidth),
            height: Int(screenHeight)
        )

        guard let capturedImage = image else {
            print("截图失败")
            screenshotDelegate?.didCaptureScreenshot(nil, fileURL: nil)
            return nil
        }

        var fileURL: URL? = nil

        // 保存到文档目录
        if saveToFile {
            fileURL = screenshotManager.saveToDocuments(capturedImage)
            if let url = fileURL {
                print("截图已保存到文档目录: \(url.path)")
            }
        }

        // 保存到相册
        if saveToPhotoLibrary {
            screenshotManager.saveToPhotoLibrary(capturedImage) {
                success,
                error in
                if success {
                    print("截图已保存到相册")
                } else {
                    print("保存到相册失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }

        // 通知代理
        screenshotDelegate?.didCaptureScreenshot(
            capturedImage,
            fileURL: fileURL
        )

        return capturedImage
    }

    /// 获取所有截图文件
    func getAllScreenshots() -> [URL] {
        return screenshotManager.getAllScreenshots()
    }

    /// 删除截图文件
    func deleteScreenshot(at url: URL) -> Bool {
        return screenshotManager.deleteScreenshot(at: url)
    }

    // MARK: - Recording Methods

    /// 开始录制视频
    func startRecording(outputURL: URL, playbackSpeed: Double = 1.0) -> Bool {
        return videoRecorder.startRecording(
            outputURL: outputURL,
            playbackSpeed: playbackSpeed
        )
    }

    /// 停止录制视频
    func stopRecording(completion: @escaping (Bool, URL?) -> Void) {
        videoRecorder.stopRecording(completion: completion)
    }

    /// 获取录制状态
    var isRecording: Bool {
        return videoRecorder.isRecording
    }

    /// 获取已录制的帧数
    var recordedFrameCount: Int64 {
        return videoRecorder.frameCount
    }

    @objc private func updateTexture() {
        updateViewTexture()
    }
}

// MARK: - VideoRecorderDelegate

extension RenderFromViewTexture: VideoRecorderDelegate {

    func videoRecorderDidStartRecording(_ recorder: VideoRecorder) {
        print("📹 录制开始")
    }

    func videoRecorderDidStopRecording(
        _ recorder: VideoRecorder,
        success: Bool,
        outputURL: URL?
    ) {
        if success, let url = outputURL {
            print("✅ 录制成功，保存至: \(url.path)")
            print("📊 总共录制帧数: \(recorder.frameCount)")
        } else {
            print("❌ 录制失败")
        }
    }

    func videoRecorderDidCaptureFrame(
        _ recorder: VideoRecorder,
        frameCount: Int64
    ) {
        if frameCount % 30 == 0 {
            print("📹 已录制 \(frameCount) 帧")
        }
    }
}
