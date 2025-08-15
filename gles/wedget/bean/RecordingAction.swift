//
//  Untitled.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

// MARK: - 录制动作枚举
import SwiftUI

public enum RecordingAction {
    case captureOverlay(AnyView, CGRect, CGRect)
    case loadTexture
    case updateTexture(Int)
    case startRecording
    case stopRecording
}
