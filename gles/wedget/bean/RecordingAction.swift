//
//  Untitled.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

// MARK: - 录制动作枚举
import SwiftUI

// 扩展 RecordingAction 枚举，添加截图相关操作
public enum RecordingAction: Equatable {
    case captureOverlay(AnyView, CGRect, CGRect)
    case startRecording
    case stopRecording
    case loadTexture
    case updateTexture(Int)
    case takeScreenshot  // 新增：截图操作
    
    static public func == (lhs: RecordingAction, rhs: RecordingAction) -> Bool {
        switch (lhs, rhs) {
        case (.captureOverlay, .captureOverlay),
             (.startRecording, .startRecording),
             (.stopRecording, .stopRecording),
             (.loadTexture, .loadTexture),
             (.takeScreenshot, .takeScreenshot):
            return true
        case let (.updateTexture(l), .updateTexture(r)):
            return l == r
        default:
            return false
        }
    }
}
