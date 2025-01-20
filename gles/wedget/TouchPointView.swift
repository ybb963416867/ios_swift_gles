import SwiftUI

public struct TouchPointView: View {
    public init(){}
    @State private var touchLocation: CGPoint = .zero

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景区域，用于捕获触摸事件
                Color.white.opacity(0.01)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // 调整 Y 坐标以考虑安全区域和标题栏高度，并修正圆心坐标
                                let safeAreaOffset = geometry.safeAreaInsets.top
                                touchLocation = CGPoint(
                                    x: max(0, min(value.location.x, geometry.size.width)),
                                    y: max(0 + safeAreaOffset, min(value.location.y, geometry.size.height))
                                )
                            }
                    )
                    .ignoresSafeArea()

                // 显示触摸点的坐标
                VStack {
                    Text("\(Int(touchLocation.x)), \(Int(touchLocation.y))")
                        .font(.headline)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top, 0)

                    Spacer()
                }

                // 圆形指示器
                Circle()
                    .fill(Color.red)
                    .frame(width: 30, height: 30)
                    .position(CGPoint(x: touchLocation.x, y: touchLocation.y))
            }
        }
    }
}
