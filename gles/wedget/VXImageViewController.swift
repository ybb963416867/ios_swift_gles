//
//  VXImageViewController.swift
//  OpenGLES-绘图
//
//  Created by yunshen on 2025/1/16.
//

import UIKit
import GLKit
import SwiftUI

class VXImageViewController: GLKViewController {
    
    private var mContext: EAGLContext?
    private var mPrograme = GLuint()
    
    private var vertexBuffer = GLuint()
    private var texCoordBuffer = GLuint()
    
    private var texture: GLuint = 0
    
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
        
        // 初始化 OpenGL 资源
        setupGL()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let glkView = self.view as! GLKView
        print("glkview width = \(glkView.bounds.width), glkview height = \(glkView.bounds.height)")
        let width : GLsizei = GLsizei(glkView.bounds.width)
        let height : GLsizei = GLsizei(glkView.bounds.height)
        glViewport(0, 0, width, height)
    }
    
    private func setupGL() {
        // 加载着色器
        loadPrograme()
        
        // 初始化顶点数据
        setupVertexData()
        
        // 加载纹理
        texture = loadTexture(named: "cc.jpg")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        isPaused = true
    }
    
    private func setupVertexData() {
        
        let vertexData: [GLfloat] = [
            -1, 1, 0.0,  // 左上角
             -1, -1, 0.0,  // 左下角
             1, -1, 0.0,  // 右下角
             1, 1, 0.0 // 右上角
        ]
        
        let texCoords: [GLfloat] = [
            0.0, 0.0,
            0.0, 1.0,
            1.0, 1.0,
            1.0, 0.0
        ]
        
        // 生成顶点缓冲区
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertexData.count * MemoryLayout<GLfloat>.size, vertexData, GLenum(GL_STATIC_DRAW))
        
        glGenBuffers(1, &texCoordBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), texCoords.count * MemoryLayout<GLfloat>.size, texCoords, GLenum(GL_STATIC_DRAW))
        
    }
    
    private func loadPrograme() {
        let bundlePath = Bundle(for: VXImageViewController.self).path(forResource: "gles", ofType: "bundle")!
        
        let verterShaderStr = Gl2Utils.loadBundleFile(bundlePath: bundlePath, forResource: "shaderv", ofType: "vsh")
        
        let fragmentShaderStr = Gl2Utils.loadBundleFile(bundlePath: bundlePath, forResource: "shaderf", ofType: "fsh")
        
        mPrograme = Gl2Utils.loadProgram(vSource: verterShaderStr, fSource: fragmentShaderStr)
    }
    
    private func compileShader(shader: inout GLuint, type: GLenum, filePath: String) {
        let shaderString = try! String(contentsOfFile: filePath, encoding: .utf8)
        shaderString.withCString(){ pointer in
            var source: UnsafePointer<GLchar>? = pointer
            shader = glCreateShader(type)
            glShaderSource(shader, 1, &source, nil)
            glCompileShader(shader)
        }
        
    }
    
    private func loadTexture(named name: String) -> GLuint {
        let moduleBundle = Bundle(for: VXImageViewController.self)
        guard   let spriteImage = UIImage(named: "cc.jpg", in: moduleBundle, compatibleWith: nil)?.cgImage else {
            fatalError("无法加载子模块的图片")
        }
        
        return Gl2Utils.createTexture(cgImage: spriteImage).first
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(0.1, 0.2, 0.3, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        glUseProgram(mPrograme)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        
        let positionHandle = GLuint(glGetAttribLocation(mPrograme, "vPosition"))
        glEnableVertexAttribArray(positionHandle)
        glVertexAttribPointer(positionHandle, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 3), nil)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        let texCoordHandle = GLuint(glGetAttribLocation(mPrograme, "vCoord"))
        glEnableVertexAttribArray(texCoordHandle)
        glVertexAttribPointer(texCoordHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 2), nil)
        //BUFFER_OFFSET(MemoryLayout<GLfloat>.size * 3)
        
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glUniform1i(glGetUniformLocation(mPrograme, "vTexture"), 0)
        
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4)
        
        glDisableVertexAttribArray(positionHandle)
        glDisableVertexAttribArray(texCoordHandle)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER),  0)
        print("glkView")
    }
    
    private func BUFFER_OFFSET(_ i: Int) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: i)
    }
    
    deinit {
        EAGLContext.setCurrent(nil)
        if vertexBuffer != 0 {
            glDeleteBuffers(1, &vertexBuffer)
        }
        
        if texCoordBuffer != 0 {
            glDeleteBuffers(1, &texCoordBuffer)
        }
        if texture != 0 {
            glDeleteTextures(1, &texture)
        }
    }
}


public struct GLKViewControllerWrapper1: UIViewControllerRepresentable {
    
    public init() {}
    
    public func makeUIViewController(context: Context) -> GLKViewController {
        
        return VXImageViewController()
    }
    
    public func updateUIViewController(_ uiViewController: GLKViewController, context: Context) {
        // 不需要更新逻辑，渲染由 GLKViewController 控制
    }
}
