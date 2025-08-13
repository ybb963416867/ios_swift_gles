//
//  YSGSImageView.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/16.
//

import GLKit
import SwiftUI
import UIKit

class YSGSImageView1: GLKViewController {

    private var mContext: EAGLContext?
    private var viewProvider: (() -> (AnyView, CGRect))? = nil
    func setViewProvider(_ provider: @escaping () -> (AnyView, CGRect)) {
        self.viewProvider = provider
        render.setViewProvider(provider)
    }
    private var button: UIButton!
    private var render: Render!
    private var isProcessingAction: Bool = false

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

        render = Render(glkView: glkView)

        render.onSurfaceCreate(context: context)
    }

    override func viewSafeAreaInsetsDidChange() {
        if let glkView = self.view as? GLKView {
            glkView.frame = self.view.bounds.inset(by: .zero)
        }
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

    private func BUFFER_OFFSET(_ i: Int) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: i)
    }

    func handleRecordingAction(_ action: RecordingAction) {

        guard !isProcessingAction else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            defer { isProcessingAction = false }

            switch action {
            case .captureOverlay(let view, let cgRect):
                setViewProvider { (view, cgRect) }
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
                    render.test()
                } else if index == 1 {
                    render.test2()
                } else if index == 2 {
                    render.textUIImage()
                } else if index == 3 {
                    render.updateUITexture()
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

public struct YSGSImageViewWrapper1: UIViewControllerRepresentable {
    @Binding var recordingAction: RecordingAction?

    public init(recordingAction: Binding<RecordingAction?> = .constant(nil)) {
        self._recordingAction = recordingAction
    }

    public func makeUIViewController(context: Context) -> GLKViewController {
        let vc = YSGSImageView1()
        vc.preferredContentSize = CGSize(width: 1080, height: 720)
        return vc
    }

    public func updateUIViewController(
        _ uiViewController: GLKViewController,
        context: Context
    ) {
        // 不需要更新逻辑，渲染由 GLKViewController 控制
        if let action = recordingAction {
            if let controller = uiViewController as? YSGSImageView1 {
                controller.handleRecordingAction(action)
            }

            DispatchQueue.main.async {
                recordingAction = nil
            }
        }
    }
}
