//
//  ViewFinder.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

import UIKit
import SwiftUI

// MARK: - 视图查找工具类
class ViewFinder {
    
    // MARK: - 1. 基础查找方法
    
    /// 递归查找具有指定 identifier 的视图
    static func findView(withIdentifier identifier: String, in view: UIView) -> UIView? {
        // 检查当前视图
        if view.accessibilityIdentifier == identifier {
            return view
        }
        
        // 递归检查所有子视图
        for subview in view.subviews {
            if let found = findView(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        
        return nil
    }
}


// MARK: - SwiftUI 视图扩展，确保 identifier 被正确设置

struct IdentifiableView<Content: View>: UIViewRepresentable {
    let identifier: String
    let content: Content
    
    func makeUIView(context: Context) -> UIView {
        let hostingController = UIHostingController(rootView: content)
        let view = hostingController.view!
        view.isOpaque = false
        view.accessibilityIdentifier = identifier
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// 方案2: 创建一个专门的透明背景包装器
struct TransparentBackgroundWrapper<Content: View>: View {
    let content: Content
    
    var body: some View {
        ZStack {
            // 添加一个完全透明但明确存在的背景层
            Color.white.opacity(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            content
        }
    }
}

struct IdentifiableViewV1<Content: View>: UIViewRepresentable {
    let identifier: String
    let content: Content
    
    func makeUIView(context: Context) -> UIView {
        let wrappedContent = TransparentBackgroundWrapper(content: content)
        let hostingController = UIHostingController(rootView: wrappedContent)
        let view = hostingController.view!
        view.isOpaque = false
        view.accessibilityIdentifier = identifier
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}


// 使用扩展来包装 SwiftUI 视图
extension View {
    func identifiable(_ identifier: String) -> some View {
        IdentifiableView(identifier: identifier, content: self)
    }
    
    // V2版本
    func identifiableV1(_ identifier: String) -> some View {
        IdentifiableViewV1(identifier: identifier, content: self)
    }
}
