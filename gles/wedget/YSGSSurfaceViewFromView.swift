//
//  YSGSSurfaceViewFromView.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

import GLKit
import SwiftUI

class YSGSSurfaceViewFromView: GLKViewController {
    private var mContext: EAGLContext?
    private var render: RenderFromViewTexture!
    private var isProcessingAction = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // 初始化 OpenGL 上下文
        mContext = EAGLContext(api: .openGLES3)
        guard let context = mContext else {
            fatalError("无法创建 OpenGL 上下文")
        }
        EAGLContext.setCurrent(context)

        // 配置 GLKView
        let glkView = self.view as! GLKView
        glkView.context = context
        glkView.drawableDepthFormat = .format24
        render = RenderFromViewTexture(glkView: glkView)

        render.onSurfaceCreate(context: context)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let glkView = self.view as! GLKView

        let width: GLsizei = GLsizei(glkView.bounds.width)
        let height: GLsizei = GLsizei(glkView.bounds.height)
        render.onSurfaceChanged(width: Int(width), height: Int(height))
    }

    override func viewDidAppear(_ animated: Bool) {
        isPaused = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        isPaused = true
    }

    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        render.onDrawFrame()
    }

    func handleRecordingAction(_ action: RecordingAction) {

        guard !isProcessingAction else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            defer { isProcessingAction = false }

            switch action {
            case .captureOverlay(_, _, let cgGlobalRect):
                self.render.setRect(cgGlobalRect)
                break
            case .startRecording:
                startRecoder()
                break
            case .stopRecording:
                stopRecoder()
                break
            case .loadTexture:
                render.loadTexture()
                break
            case .updateTexture(let index):
                if index == 0 {
                    self.render.updateViewTexture()
                } else if index == 1 {
                    render.start()
                } else if index == 2 {
                    render.stop()
                } else if index == 3 {
                    render.updateViewTexturePostion()
                } else if index == 4 {
                    render.test()
                }
                break
            }
        }
    }
    
    private func startRecoder() {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let videoURL = documentsPath.appendingPathComponent(
            "video_\(timestamp).mp4"
        )
        let result = render.startRecording(outputURL: videoURL)
        if result {
            print("开始录制 path = \(videoURL)")
        } else {
            print("开始录制失败")
        }
    }

    private func stopRecoder() {
        render.stopRecording { status, url in
            if status {
                print("录制成功 path = \(url?.absoluteString ?? "")")
            } else {
                print("录制失败")
            }
        }
    }

    deinit {
        EAGLContext.setCurrent(nil)
        render.release()
    }
}

public struct YSGSSurfaceViewFromViewWrapper: UIViewControllerRepresentable {
    @Binding var recordingAction: RecordingAction?

    public init(recordingAction: Binding<RecordingAction?> = .constant(nil)) {
        self._recordingAction = recordingAction
    }

    public func makeUIViewController(context: Context) -> GLKViewController {
        return YSGSSurfaceViewFromView()
    }

    public func updateUIViewController(
        _ uiViewController: GLKViewController,
        context: Context
    ) {
        // 不需要更新逻辑，渲染由 GLKViewController 控制
        if let action = recordingAction {
            if let controller = uiViewController as? YSGSSurfaceViewFromView {
                controller.handleRecordingAction(action)
            }

            DispatchQueue.main.async {
                recordingAction = nil
            }
        }
    }
}
