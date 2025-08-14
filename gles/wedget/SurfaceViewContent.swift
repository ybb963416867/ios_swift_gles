//
//  SurfaceViewContent.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/11.
//

import SwiftUI

// MARK: - 录制动作枚举
public enum RecordingAction {
    case captureOverlay(AnyView, CGRect, CGRect)
    case loadTexture
    case updateTexture(Int)
    case startRecording
    case stopRecording
}

public struct SurfaceViewContent: View {

    // 用于传递录制指令的状态
    @State private var recordingAction: RecordingAction?
    @State private var cgRect: CGRect = .zero
    @State private var cgGlobalRect: CGRect = .zero

    public init() {

    }

    public var body: some View {
        ZStack {
            ZStack {

                GeometryReader { geo in
                    Rectangle().fill(Color.black.opacity(0.1)).onAppear {
                        cgRect = CGRect(origin: .zero, size: geo.size)
                        cgGlobalRect = geo.frame(in: .global)
                        recordingAction = .captureOverlay(AnyView(overlayViews), cgRect, cgGlobalRect)
                        print("safeAreaInsets = \(geo.safeAreaInsets) cgGlobalRect = \(cgGlobalRect)")
                    }.onChange(of: geo.frame(in: .global)) { oldValue, newValue in
                        cgRect = CGRect(origin: .zero, size: geo.size)
                        cgGlobalRect = geo.frame(in: .global)
                        recordingAction = .captureOverlay(AnyView(overlayViews), cgRect, cgGlobalRect)
                        print("onChange safeAreaInsets = \(geo.safeAreaInsets) cgGlobalRect = \(cgGlobalRect)")
                    }
                    
                    
                    YSGSImageViewWrapper1(recordingAction: $recordingAction)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )

                    ///如果在 这里加载这个怎么录制这个view
                    overlayViews
                    controlButtons

                }

            }.frame(width: UIScreen.main.bounds.width - 200, height: UIScreen.main.bounds.height - 200)
        }
    }

    private var overlayViews: some View {

        ZStack {
            ZStack {
                FloatView {
                    Color.blue.opacity(0.5).frame(maxWidth: 100, maxHeight: 100)
                }
          

            }.frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topTrailing
            )

            ZStack {

                Color.orange.opacity(0.5).frame(maxWidth: 100, maxHeight: 100)

            }.frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomTrailing
            )

        }.background(Color.yellow.opacity(0.2))

    }

    // 控制按钮
    private var controlButtons: some View {
        VStack {
            HStack {
                // 录制控制按钮
                VStack(spacing: 8) {
                    
                    Button("加载ui纹理") {
                        recordingAction = .captureOverlay(AnyView(overlayViews), cgRect, cgGlobalRect)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)

                    Button("加载普通纹理") {
                        recordingAction = .loadTexture
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(5)

                    Button("更新纹理0") {
                        recordingAction = .updateTexture(0)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.brown.opacity(0.3))
                    .foregroundColor(Color.white)
                    .cornerRadius(5)

                    Button("更新纹理1") {
                        recordingAction = .updateTexture(1)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.primary.opacity(0.3))
                    .foregroundColor(Color.white)
                    .cornerRadius(5)

                    Button("更新UI纹理的位置") {
                        recordingAction = .updateTexture(2)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.indigo.opacity(0.3))
                    .foregroundColor(Color.white)
                    .cornerRadius(5)
                    
                    Button("更新UI纹理") {
                        recordingAction = .updateTexture(3)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.pink.opacity(0.3))
                    .foregroundColor(Color.white)
                    .cornerRadius(5)

                    Button("开始录制") {
                        recordingAction = .startRecording
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(6)

                    Button("停止录制") {
                        recordingAction = .stopRecording
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(6)
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
