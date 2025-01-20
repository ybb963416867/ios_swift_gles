//
//  YSGLView.swift
//  wscanner
//
//  Created by yunshen on 2025/1/16.
//

import UIKit
import GLKit
import SwiftUI

class YSGLView: GLKViewController {
    private var glContext: EAGLContext?
    
    var glkUpdater :GLKUpdate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化 OpenGL 上下文
        glContext = EAGLContext(api: .openGLES2)
        guard let context = glContext else {
            fatalError("无法创建 OpenGL ES 上下文")
        }
        
        // 配置 GLKView
        let glkView = self.view as! GLKView
        glkView.context = context
        glkView.drawableDepthFormat = .format24
        // 设置当前上下文
        EAGLContext.setCurrent(context)
        glkUpdater = GLKUpdate(glKViewControler: self)
        
        self.delegate = glkUpdater
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("隐藏")
        self.isPaused = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("显示")
        self.isPaused = false
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        // 渲染逻辑
        glClearColor(Float(glkUpdater.redValue), 0.0, 0.0, 1.0) // 背景色
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
    }
}

class GLKUpdate:NSObject, GLKViewControllerDelegate{
    var redValue : Double = 0.0
    let durationOfFlash : Double = 2.0
    private weak var glKViewControler : GLKViewController!
    
    init(glKViewControler : GLKViewController) {
        self.glKViewControler = glKViewControler
    }
    func glkViewControllerUpdate(_ controller: GLKViewController) {
        
        redValue = (sin(self.glKViewControler.timeSinceFirstResume * 2 * Double.pi / durationOfFlash) * 0.5) + 0.5
        
        //        print(self.glKViewControler.timeSinceFirstResume)
    }
}


public struct GLKViewControllerWrapper: UIViewControllerRepresentable {
    
    public init() {}
    
    public func makeUIViewController(context: Context) -> GLKViewController {
        
        return YSGLView()
    }
    
    public func updateUIViewController(_ uiViewController: GLKViewController, context: Context) {
        // 不需要更新逻辑，渲染由 GLKViewController 控制
    }
}
