//
//  CaptrueView.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/13.
//

import SwiftUI

public struct CaptrueView: View {

    public init() {

    }
    public var body: some View {

        ZStack {
            ZStack {
                ///如果在 这里加载这个怎么录制这个view
                overlayViews
                controlButtons

            }

        }.frame(
            width: UIScreen.main.bounds.width - 200,
            height: UIScreen.main.bounds.height - 200
        )
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

    }.background(Color.yellow.opacity(0.4))

}

// 控制按钮
private var controlButtons: some View {
    VStack {
        HStack {
            // 录制控制按钮
            VStack(spacing: 8) {

                Button("截图") {

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
