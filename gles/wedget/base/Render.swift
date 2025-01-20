//
//  Render.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/18.
//

import GLKit

class Render : IRender{
    
    private var glkView: GLKView
    
    private var imageTexture : IBaseTexture!
    
    init(glkView: GLKView) {
        self.glkView = glkView
        imageTexture = ImageTexture(glkView: glkView, vertPath: "base_vert", fragPath: "base_frag")
    }
    
    
    func onSurfaceCreate(context: EAGLContext) {
        imageTexture.onSurfaceCreated()
    }
    
    func onSurfaceChanged(width: Int, height: Int) {
        glViewport(0, 0, GLsizei(width), GLsizei(height))
        imageTexture.onSurfaceChanged(screenWidth: width, screenHeight: height)
    }
    
    func onDrawFrame() {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        imageTexture.onDrawFrame()
    }
    
    func loadTexture(){
        let moduleBundle = Bundle(for: VXImageViewController.self)
        guard let spriteImage = UIImage(named: "cc.jpg", in: moduleBundle, compatibleWith: nil)?.cgImage else {
            fatalError("无法加载子模块的图片")
        }
        let result = imageTexture.getTextureInfo().generateBitmapTexture(cgImage: spriteImage)
        
        imageTexture.updateTextureInfo(textureInfo: result, isRecoverCord: false, iTextureVisibility: ITextureVisibility.VISIBLE)
        
        glkView.setNeedsDisplay()
        
    }
    
    func test(){
        let coordinateRegion = CoordinateRegion().generateCoordinateRegion(left: 0, top: 0, width: 200, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTexture.updateTexCord(coordinateRegion: coordinateRegion)
        
        glkView.setNeedsDisplay()
    }
    
    
    func release() {
        imageTexture.release()
    }
    
    
}

