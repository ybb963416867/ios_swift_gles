
//
//  FloatView.swift
//  wscanner
//
//  Created by yunshen on 2025/6/18.
//
import Foundation
import SwiftUI

/// 吸边类型
/// - `.horizontal` 水平吸边
/// - `.vertical` 垂直吸边
/// - `.all` 靠近那边吸那边
public enum SnapToEdgeAlignment {
    /// `.horizontal` 水平吸边
    case horizontal
    /// `.vertical` 垂直吸边
    case vertical
    /// `.all` 靠近那边吸那边
    case all
}

public struct FloatView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State var contentSize: CGSize = .zero
    
    // 使用 @GestureState 来跟踪拖拽状态
    @GestureState var isDragging = false
    
    // 使用 @State 来保存拖拽过程中需要的数据
    @State private var dragStartOffset: CGPoint = .zero
    @State private var regionRect: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) = (0, 0, 0, 0)
    
    @State var currentPoint: CGPoint = .zero
    
    /// `alignment` 相对父控件中的对其方式
    let alignment: Alignment

    /// `enableSnapToEdge` 吸边控制的开关
    let enableSnapToEdge: Bool
    /// `snapAnimationDuration` 开启吸边控制后，吸边的动画时间
    let snapAnimationDuration: Double
    /// `snapEdgeAlignment` enableSnapToEdge 为true时生效，吸边的方式
    var snapEdgeAlignment: SnapToEdgeAlignment

    /// - Parameter:
    ///   - alignment 相对父控件中的对其方式 记得设置父容器的大小
    ///   - offset 初始化时，在 alignment 位置基础上的偏移量
    ///   - enableSnapToEdge 开启吸边的效果
    ///   - snapAnimationDuration 吸边时的动画时间
    ///   - snapEdgeAlignment enableSnapToEdge 为true时生效，吸边的方式
    ///   - content 控件
    public init(
        alignment: Alignment = .trailing,
        offset: CGPoint = .zero,
        enableSnapToEdge: Bool = false,
        snapAnimationDuration: Double = 0.3,
        snapEdgeAlignment: SnapToEdgeAlignment = .all,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.content = content
        self.enableSnapToEdge = enableSnapToEdge
        self.snapAnimationDuration = snapAnimationDuration
        self.snapEdgeAlignment = snapEdgeAlignment
        self._currentPoint = State(initialValue: offset)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                content()
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.onAppear {
                                contentSize = contentGeo.size
                            }
                        }
                    )
                    .offset(x: currentPoint.x, y: currentPoint.y)
                    .simultaneousGesture(
                        getGesture(geometry: geometry),
                        isEnabled: true
                    )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: alignment
            )
        }
    }

    // 计算边界限制（根据对齐方式调整）
    private func getBounds(geometry: GeometryProxy) -> (
        minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat
    ) {
        let containerSize = geometry.size
        let safeArea = geometry.safeAreaInsets

        // 计算初始位置（SwiftUI 自动放置的位置）
        let initialPosition = getInitialPositionForAlignment(geometry: geometry)

        // 计算整个容器的可用边界
        let containerMinX =
            -containerSize.width / 2 + contentSize.width / 2 + safeArea.leading
        let containerMaxX =
            containerSize.width / 2 - contentSize.width / 2 - safeArea.trailing
        let containerMinY =
            -containerSize.height / 2 + contentSize.height / 2 + safeArea.top
        let containerMaxY =
            containerSize.height / 2 - contentSize.height / 2 - safeArea.bottom

        // 计算相对于初始位置的偏移边界
        let minX = containerMinX - initialPosition.x
        let maxX = containerMaxX - initialPosition.x
        let minY = containerMinY - initialPosition.y
        let maxY = containerMaxY - initialPosition.y

        return (minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    // 计算初始位置（与 SwiftUI 的 frame(alignment:) 保持一致）
    private func getInitialPositionForAlignment(geometry: GeometryProxy)
        -> CGPoint
    {
        let containerSize = geometry.size
        let safeArea = geometry.safeAreaInsets

        // 可用区域的实际边界
        let availableWidth =
            containerSize.width - safeArea.leading - safeArea.trailing
        let availableHeight =
            containerSize.height - safeArea.top - safeArea.bottom

        // 可用区域的中心点
        let availableCenterX =
            safeArea.leading + availableWidth / 2 - containerSize.width / 2
        let availableCenterY =
            safeArea.top + availableHeight / 2 - containerSize.height / 2

        switch alignment {
        case .topLeading:
            return CGPoint(
                x: availableCenterX - availableWidth / 2 + contentSize.width
                    / 2,
                y: availableCenterY - availableHeight / 2 + contentSize.height
                    / 2
            )
        case .top:
            return CGPoint(
                x: availableCenterX,
                y: availableCenterY - availableHeight / 2 + contentSize.height
                    / 2
            )
        case .topTrailing:
            return CGPoint(
                x: availableCenterX + availableWidth / 2 - contentSize.width
                    / 2,
                y: availableCenterY - availableHeight / 2 + contentSize.height
                    / 2
            )
        case .leading:
            return CGPoint(
                x: availableCenterX - availableWidth / 2 + contentSize.width
                    / 2,
                y: availableCenterY
            )
        case .center:
            return CGPoint(x: availableCenterX, y: availableCenterY)
        case .trailing:
            return CGPoint(
                x: availableCenterX + availableWidth / 2 - contentSize.width
                    / 2,
                y: availableCenterY
            )
        case .bottomLeading:
            return CGPoint(
                x: availableCenterX - availableWidth / 2 + contentSize.width
                    / 2,
                y: availableCenterY + availableHeight / 2 - contentSize.height
                    / 2
            )
        case .bottom:
            return CGPoint(
                x: availableCenterX,
                y: availableCenterY + availableHeight / 2 - contentSize.height
                    / 2
            )
        case .bottomTrailing:
            return CGPoint(
                x: availableCenterX + availableWidth / 2 - contentSize.width
                    / 2,
                y: availableCenterY + availableHeight / 2 - contentSize.height
                    / 2
            )
        default:
            return CGPoint(x: availableCenterX, y: availableCenterY)
        }
    }

    // 限制位置在边界内
    private func clampToBounds(
        _ point: CGPoint,
        geometry: GeometryProxy,
        bounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)
    ) -> CGPoint {
        let clampedX = max(bounds.minX, min(bounds.maxX, point.x))
        let clampedY = max(bounds.minY, min(bounds.maxY, point.y))

        return CGPoint(x: clampedX, y: clampedY)
    }

    // 计算吸边位置
    private func calculateSnapPosition(
        _ point: CGPoint,
        bounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat),
        snapEdgeAlignment: SnapToEdgeAlignment
    ) -> CGPoint {
        guard enableSnapToEdge else { return point }
        var snapPoint = point

        // 计算到各边的距离
        let distanceToLeft = abs(point.x - bounds.minX)
        let distanceToRight = abs(point.x - bounds.maxX)
        let distanceToTop = abs(point.y - bounds.minY)
        let distanceToBottom = abs(point.y - bounds.maxY)

        switch snapEdgeAlignment {
        case .horizontal:
            let minDistance = min(distanceToLeft, distanceToRight)
            if minDistance == distanceToLeft {
                snapPoint.x = bounds.minX
            } else if minDistance == distanceToRight {
                snapPoint.x = bounds.maxX
            }
        case .vertical:
            let minDistance = min(distanceToTop, distanceToBottom)
            if minDistance == distanceToTop {
                snapPoint.y = bounds.minY
            } else if minDistance == distanceToBottom {
                snapPoint.y = bounds.maxY
            }
        case .all:
            // 找到最近的边
            let minDistance = min(
                distanceToLeft,
                distanceToRight,
                distanceToTop,
                distanceToBottom
            )
            // 根据最近的边进行吸边
            if minDistance == distanceToLeft {
                snapPoint.x = bounds.minX
            } else if minDistance == distanceToRight {
                snapPoint.x = bounds.maxX
            } else if minDistance == distanceToTop {
                snapPoint.y = bounds.minY
            } else if minDistance == distanceToBottom {
                snapPoint.y = bounds.maxY
            }
        }

        return snapPoint
    }

    private func getGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($isDragging) { value, state, transaction in
                state = true
            }
            .onChanged { value in
                // 在第一次 onChanged 时初始化（避免在 updating 中修改 @State）
                if dragStartOffset == .zero && regionRect == (0, 0, 0, 0) {
                    dragStartOffset = currentPoint
                    regionRect = getBounds(geometry: geometry)
                }
                
                let newPoint = CGPoint(
                    x: dragStartOffset.x + value.translation.width,
                    y: dragStartOffset.y + value.translation.height
                )
                // 应用边界限制
                currentPoint = clampToBounds(
                    newPoint,
                    geometry: geometry,
                    bounds: regionRect
                )
            }
            .onEnded { value in
                // 保存当前的边界和起始偏移，因为 onEnded 可能在 updating 重置之后执行
                let currentBounds = regionRect
                let currentStartOffset = dragStartOffset
                
                let newPoint = CGPoint(
                    x: currentStartOffset.x + value.translation.width,
                    y: currentStartOffset.y + value.translation.height
                )
                // 应用边界限制
                let clampedPoint = clampToBounds(
                    newPoint,
                    geometry: geometry,
                    bounds: currentBounds
                )

                // 如果启用吸边效果，计算吸边位置并添加动画
                if enableSnapToEdge {
                    let snapPoint = calculateSnapPosition(
                        clampedPoint,
                        bounds: currentBounds,
                        snapEdgeAlignment: snapEdgeAlignment
                    )
                    withAnimation(.easeOut(duration: snapAnimationDuration)) {
                        currentPoint = snapPoint
                    }
                } else {
                    currentPoint = clampedPoint
                }
                
                // 重置拖拽状态
                dragStartOffset = .zero
                regionRect = (0, 0, 0, 0)
            }
    }
}



