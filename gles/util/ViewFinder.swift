//
//  ViewFinder.swift
//  swift_gles
//
//  Created by yunshen on 2025/8/14.
//

import UIKit
import SwiftUI


// MARK: - SwiftUI 视图扩展，确保 identifier 被正确设置

struct IdentifiableView<Content: View>: UIViewRepresentable {
    let identifier: String
    let content: Content
    func updateUIView(_ uiView: UIViewType, context: Context) {
        ViewRegistry.shared.register(uiView, identifier: identifier)
    }
    func makeUIView(context: Context) -> some UIView {
        print("findViewByIdentifier makeUIView")
        let hostingController = UIHostingController(rootView: content)
        let view = hostingController.view!
        view.isOpaque = false
        view.accessibilityIdentifier = identifier
        view.backgroundColor = .clear
        ViewRegistry.shared.register(view, identifier: identifier)
        
        return view
    }

}


public class ViewRegistry {
    public static let shared = ViewRegistry()
    private var views = [String: Weak<UIView>]()
    
    class Weak<T: AnyObject> {
        weak var value: T?
        init(_ value: T) { self.value = value }
    }
    
    public func register(_ view: UIView, identifier: String) {
        views[identifier] = Weak(view)
        
        // 同时设置 accessibilityIdentifier 作为备用
        view.accessibilityIdentifier = identifier
    }
    
    public func find(_ identifier: String) -> UIView? {
        // 先尝试从注册表找
        if let view = views[identifier]?.value {
            print("findViewByIdentifier = 找到了")
            return view
        }
        
       guard let windowScene = UIApplication.shared.connectedScenes.first
            as? UIWindowScene,
        let window = windowScene.windows.first,
             let rootView = window.rootViewController?.view else {
           return nil
       }
        return rootView.findViewByIdentifier(identifier)
    }
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


// 使用扩展来包装 SwiftUI 视图
extension View {
    func identifiable(_ identifier: String) -> some View {
        IdentifiableView(identifier: identifier, content: self)
    }
    
}
