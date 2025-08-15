import AVFoundation
import GLKit
import SwiftUI

// MARK: - 重构后的渲染类
class RenderFromViewTexture: IRender {
    
    // MARK: - Properties
    
    private var glkView: GLKView
    private var displayLink: CADisplayLink?
    
    private var combineTexture: MultipleFboCombineTexture!
    private var screenWidth = GLsizei()
    private var screenHeight = GLsizei()
    
    private var imageTextureList: [IBaseTexture]
    private var rect: CGRect = .zero
    private var frameInterval: Int = 20
    private var rootView: UIView? = nil
    private var isLoadTexture = false
    
    // 视频录制器
    private var videoRecorder: VideoRecorder
    private var recordingContext: EAGLContext?
    
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
        
        // 渲染到第二个 FBO（用于录制）
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
            videoRecorder.captureFrame(from: combineTexture.getFboFrameBuffer()[1])
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
    
    func release() {
        imageTextureList.forEach { it in
            it.release()
        }
        combineTexture.release()
        displayLink?.invalidate()
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
    
    // MARK: - Private Methods
    
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
    
    @objc private func updateTexture() {
        updateViewTexture()
    }
}

// MARK: - VideoRecorderDelegate

extension RenderFromViewTexture: VideoRecorderDelegate {
    
    func videoRecorderDidStartRecording(_ recorder: VideoRecorder) {
        print("录制开始")
        // 可以在这里添加 UI 更新或其他逻辑
    }
    
    func videoRecorderDidStopRecording(_ recorder: VideoRecorder, success: Bool, outputURL: URL?) {
        if success, let url = outputURL {
            print("录制成功，保存至: \(url.path)")
            print("总共录制帧数: \(recorder.frameCount)")
        } else {
            print("录制失败")
        }
        // 可以在这里添加 UI 更新或其他逻辑
    }
    
    func videoRecorderDidCaptureFrame(_ recorder: VideoRecorder, frameCount: Int64) {
        // 可以在这里更新进度或帧计数器
        if frameCount % 30 == 0 {
            print("已录制 \(frameCount) 帧")
        }
    }
}
