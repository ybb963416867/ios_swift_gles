//
//  Render.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/18.
//

import GLKit

class Render : IRender{
    
    private var glkView: GLKView
    
    private var combineTexture : MultipleFboCombineTexture!
    private var screenWidth = GLsizei()
    private var screenHeight = GLsizei()
    
    private var imageTextureList : [IBaseTexture]
    
    init(glkView: GLKView) {
        self.glkView = glkView
        combineTexture = MultipleFboCombineTexture(numFbo: 1, glkView: glkView, vertPath: "base_vert", fragPath: "base_frag")
        
        imageTextureList = [
            ImageTexture1(glkView: glkView, vertPath: "base_vert", fragPath: "base_frag"),
            ImageTexture(glkView: glkView, vertPath: "base_vert", fragPath: "base_frag"),
            ImageTexture1(glkView: glkView, vertPath: "base_vert", fragPath: "base_frag"),
            ImageTexture(glkView: glkView, vertPath: "base_vert", fragPath: "base_frag"),
            
        ]
    }
    
    
    func onSurfaceCreate(context: EAGLContext) {
        combineTexture.onSurfaceCreated(screenWidth: Int(glkView.bounds.width), screenHeight: Int(glkView.bounds.height))
        imageTextureList.forEach{ it in
            it.onSurfaceCreated()
        }
    }
    
    func onSurfaceChanged(width: Int, height: Int) {
        let glWidth = GLsizei(width)
        let glHeight = GLsizei(height)
        glViewport(0, 0, glWidth, glHeight)
        self.screenWidth = glWidth
        self.screenHeight = glHeight
        combineTexture.onSurfaceChanged(screenWidth: width, screenHeight: height)
        imageTextureList.forEach{ it in
            it.onSurfaceChanged(screenWidth: width, screenHeight: height)
        }
    }
    
    func onDrawFrame() {
        if EAGLContext.current() == nil {
            EAGLContext.setCurrent(glkView.context)
        }
        Gl2Utils.checkGlError()
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), combineTexture.getFboFrameBuffer()[0])
        // 设置视口为 FBO 的尺寸
        Gl2Utils.checkGlError()
        glViewport(0, 0, screenWidth, screenHeight)
        //        // 清除 FBO
        //        Gl2Utils.checkGlError()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        imageTextureList.forEach{ it in
            it.onDrawFrame()
        }
        
        glkView.deleteDrawable()
        
        // 删除旧的 Drawable
        combineTexture.onDrawFrame(textureIdIndex: 0)
        Gl2Utils.checkGlError()
        
    }
    
    func loadTexture(){
        let moduleBundle = Bundle(for: Render.self)
        guard let spriteImage = UIImage(named: "yunshen.jpg", in: moduleBundle, compatibleWith: nil)?.cgImage else {
            fatalError("无法加载子模块的图片")
        }
        let result = imageTextureList[0].getTextureInfo().generateBitmapTexture(cgImage: spriteImage)
        imageTextureList[0].updateTextureInfo(textureInfo: result, isRecoverCord: false, iTextureVisibility: ITextureVisibility.VISIBLE)
        
        
        let result1 = imageTextureList[1].getTextureInfo().generateBitmapTexture(cgImage: spriteImage)
        imageTextureList[1].updateTextureInfo(textureInfo: result1, isRecoverCord: false, iTextureVisibility: ITextureVisibility.VISIBLE)
        
        
        guard let spriteImage1 = UIImage(named: "cc.jpg", in: moduleBundle, compatibleWith: nil)?.cgImage else {
            fatalError("无法加载子模块的图片")
        }
        
        let result2 = imageTextureList[2].getTextureInfo().generateBitmapTexture(cgImage: spriteImage1)
        imageTextureList[2].updateTextureInfo(textureInfo: result2, isRecoverCord: false, iTextureVisibility: ITextureVisibility.VISIBLE)
        
        
        let result3 = imageTextureList[3].getTextureInfo().generateBitmapTexture(cgImage: spriteImage1)
        imageTextureList[3].updateTextureInfo(textureInfo: result3, isRecoverCord: false, iTextureVisibility: ITextureVisibility.VISIBLE)
        
        glkView.setNeedsDisplay()
        
    }
    
    func test(){
        let coordinateRegion = CoordinateRegion().generateCoordinateRegion(left: 0, top: 0, width: 200, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[0].updateTexCord(coordinateRegion: coordinateRegion)
        
        let coordinateRegion1 = CoordinateRegion().generateCoordinateRegion(left: 0, top: 0, width: 200, height: 200)
        imageTextureList[1].updateTexCord(coordinateRegion: coordinateRegion1)
        
        
        let coordinateRegion2 = CoordinateRegion().generateCoordinateRegion(left: 0, top: 200, width: 200, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[2].updateTexCord(coordinateRegion: coordinateRegion2)
        
        let coordinateRegion3 = CoordinateRegion().generateCoordinateRegion(left: 0, top: 200, width: 200, height: 200)
        imageTextureList[3].updateTexCord(coordinateRegion: coordinateRegion3)
        
        glkView.setNeedsDisplay()
    }
    
    func test2(){
        let coordinateRegion = CoordinateRegion().generateCoordinateRegion(left: 50, top: 100, width: 100, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[0].updateTexCord(coordinateRegion: coordinateRegion)
        
        let coordinateRegion1 = CoordinateRegion().generateCoordinateRegion(left: 50, top: 100, width: 100, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[1].updateTexCord(coordinateRegion: coordinateRegion1)
        
        let coordinateRegion2 = CoordinateRegion().generateCoordinateRegion(left: 50, top: 300, width: 100, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[2].updateTexCord(coordinateRegion: coordinateRegion2)
        
        let coordinateRegion3 = CoordinateRegion().generateCoordinateRegion(left: 50, top: 300, width: 100, height: 200)
        print("region = \(coordinateRegion) \n")
        imageTextureList[3].updateTexCord(coordinateRegion: coordinateRegion3)
        
        glkView.setNeedsDisplay()
    }
    
    
    func release() {
        imageTextureList.forEach{ it in
            it.release()
        }
        combineTexture.release()
    }
    
    
}

