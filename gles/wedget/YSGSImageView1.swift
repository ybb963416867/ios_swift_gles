//
//  YSGSImageView.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/16.
//

import UIKit
import GLKit
import SwiftUI

class YSGSImageView1: GLKViewController {
    
    private var mContext: EAGLContext?
  
    private var button: UIButton!
    private var render: Render!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化 OpenGL 上下文
        mContext = EAGLContext(api: .openGLES3)
        guard let context = mContext else {
            fatalError("无法创建 OpenGL 上下文")
        }
        EAGLContext.setCurrent(context)
        
        // 配置 GLKView
        let glkView = self.view as! GLKView
        glkView.context = context
        glkView.drawableDepthFormat = .format24
        
        render = Render(glkView: glkView)
        
        render.onSurfaceCreate(context: context)
        
        // 初始化 OpenGL 资源
        
        // 添加按钮
        setupButton()
    }
    
    
    private func setupButton() {
        // 添加 TouchPointView
        let touchPointView = UIHostingController(rootView: TouchPointView())
        touchPointView.view.frame = self.view.bounds
        touchPointView.view.backgroundColor = .clear // 确保透明背景
        self.addChild(touchPointView)
        self.view.addSubview(touchPointView.view)
        touchPointView.didMove(toParent: self)
        
        // 创建一个垂直方向的 UIStackView
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到主视图
        self.view.addSubview(stackView)
        
        // 设置约束，固定在屏幕左上角
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 5),
            stackView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 5),
            stackView.widthAnchor.constraint(equalToConstant: 120)
        ])
        
        // 添加按钮到 stackView
        let button1 = UIButton(type: .system)
        button1.setTitle("切换纹理", for: .normal)
        button1.backgroundColor = UIColor.systemBlue
        button1.tintColor = .white
        button1.layer.cornerRadius = 5
        button1.addTarget(self, action: #selector(onChangeTextureButtonTapped), for: .touchUpInside)
        button1.frame.size = CGSize(width: 100, height: 40)
        stackView.addArrangedSubview(button1)
        
        // 可以添加更多按钮
        let button2 = UIButton(type: .system)
        button2.setTitle("text", for: .normal)
        button2.backgroundColor = UIColor.systemGreen
        button2.tintColor = .white
        button2.layer.cornerRadius = 5
        button2.frame.size = CGSize(width: 100, height: 40)
        button2.addTarget(self, action: #selector(onChangeTextureTest), for: .touchUpInside)
        stackView.addArrangedSubview(button2)
        
        let button3 = UIButton(type: .system)
        button3.setTitle("按钮 3", for: .normal)
        button3.backgroundColor = UIColor.systemRed
        button3.tintColor = .white
        button3.layer.cornerRadius = 5
        button3.frame.size = CGSize(width: 100, height: 40)
        button3.addTarget(self, action: #selector(onChangeTextureTest2), for: .touchUpInside)
        stackView.addArrangedSubview(button3)
    }
    
    @objc private func onChangeTextureButtonTapped() {
        // 动态加载新的纹理
        render.loadTexture()
    }
    
    @objc private func onChangeTextureTest() {
        // 动态加载新的纹理
        render.test()
    }
    
    @objc private func onChangeTextureTest2() {
        // 动态加载新的纹理
        render.test2()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let glkView = self.view as! GLKView
        let width : GLsizei = GLsizei(glkView.bounds.width)
        let height : GLsizei = GLsizei(glkView.bounds.height)
        render.onSurfaceChanged(width: Int(width), height: Int(height))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isPaused = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        isPaused = true
    }
    
   
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        render.onDrawFrame()
    }
    
    private func BUFFER_OFFSET(_ i: Int) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: i)
    }
    
    deinit {
        EAGLContext.setCurrent(nil)
        render.release()
    }
}


public struct YSGSImageViewWrapper1: UIViewControllerRepresentable {
    
    public init() {}
    
    public func makeUIViewController(context: Context) -> GLKViewController {
        
        return YSGSImageView1()
    }
    
    public func updateUIViewController(_ uiViewController: GLKViewController, context: Context) {
        // 不需要更新逻辑，渲染由 GLKViewController 控制
    }
}
