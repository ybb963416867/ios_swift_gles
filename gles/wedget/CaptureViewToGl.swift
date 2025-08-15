//
//  CaptureViewToGl.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

import SwiftUI

public struct CaptureViewToGl: View {
    @State private var overlayFrame: CGRect = .zero
    @State private var recordingAction: RecordingAction?
    @State private var capturedScreenshot: UIImage?
    @State private var screenshotURL: URL?
    public init() {}

    public var body: some View {
        ZStack {

            VStack {
                ZStack {
                    overlayViews.identifiable("complexContainer")
                        .captureFrame(in: .global) { frame in
                            overlayFrame = frame
                            recordingAction = .captureOverlay(
                                AnyView(overlayViews),
                                CGRect(origin: .zero, size: overlayFrame.size),
                                overlayFrame
                            )
                            print("Overlay frame: \(frame)")
                        }
                    
                    controlButtons
                }

                YSGSSurfaceViewFromViewWrapper(
                    recordingAction: $recordingAction,
                    capturedScreenshot: $capturedScreenshot,
                    screenshotURL: $screenshotURL
                )
                
                ZStack {
                    if let  capturedScreenshot = capturedScreenshot {
                        Image(uiImage: capturedScreenshot)
                    } else {
                        Color.yellow.opacity(0.4)
                    }
                }
            }

        }
        .frame(
            width: UIScreen.main.bounds.width - 200,
            height: UIScreen.main.bounds.height - 200
        ).background(Color.black)
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
            .background(Color.blue.opacity(0.3))
        //.accessibilityIdentifier("complexContainer")
    }

    private var controlButtons: some View {
        VStack {
            HStack {
                VStack(spacing: 8) {
                    Button("加载纹理") {
                        recordingAction = .loadTexture
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 8) {
                    Button("加载view的纹理") {
                        recordingAction = .updateTexture(0)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.accentColor.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 8) {
                    Button("开始更新") {
                        recordingAction = .updateTexture(1)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 8) {
                    Button("停止更新") {
                        recordingAction = .updateTexture(2)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 8) {
                    Button("更新view的纹理大小") {
                        recordingAction = .updateTexture(3)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)
                
                VStack(spacing: 8) {
                    Button("开始录制") {
                        recordingAction = .startRecording
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)
                
                VStack(spacing: 8) {
                    Button("停止录制") {
                        recordingAction = .stopRecording
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.orange.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)
                
                VStack(spacing: 8) {
                    Button("截图") {
                        recordingAction = .takeScreenshot
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.indigo.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 8) {
                    Button("测试") {
                        recordingAction = .updateTexture(4)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)
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
}
