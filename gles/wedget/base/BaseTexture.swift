//
//  BaseTexture.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/18.
//


import GLKit

open class BaseTexture : IBaseTexture{
    private var glkView: GLKView
    private var vertPath: String
    private var fragPath: String
    private var screenWidth = 0
    private var screenHeight = 0
    private var shaderProgram = GLuint()
    private var positionHandle = GLuint()
    private var texCoordHandle = GLuint()
    private var uTextureHandle : Int32 = 0
    private var matrixHandle: Int32 = 0
    var matix:[GLfloat] = Array(repeating: 0.0, count: 16)
    
    private var vertexBuffer = GLuint()
    private var texCoordBuffer = GLuint()
    
    private var textureInfo = TextureInfo()
    private var iTextureVisibility = ITextureVisibility.INVISIBLE
    
    private var currentRegion = CoordinateRegion()
    
    public init(glkView: GLKView, vertPath: String, fragPath: String) {
        self.glkView = glkView
        self.vertPath = vertPath
        self.fragPath = fragPath
    }
    
    var vertexData: [GLfloat] = [
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
    
    
    func onSurfaceCreated() {
        initCoordinate()
        let bundlePath = Bundle(for: VXImageViewController.self).path(forResource: "gles", ofType: "bundle")!
        
        let verterShaderStr = Gl2Utils.loadBundleFile(bundlePath: bundlePath, forResource: vertPath, ofType: "glsl")
        
        let fragmentShaderStr = Gl2Utils.loadBundleFile(bundlePath: bundlePath, forResource: fragPath, ofType: "glsl")
        
        shaderProgram = Gl2Utils.loadProgram(vSource: verterShaderStr, fSource: fragmentShaderStr)
        
        positionHandle = GLuint(glGetAttribLocation(shaderProgram, "vPosition"))
        texCoordHandle = GLuint(glGetAttribLocation(shaderProgram, "vCoord"))
        uTextureHandle = glGetUniformLocation(shaderProgram, "vTexture")
        matrixHandle = glGetUniformLocation(shaderProgram, "vMatrix")
        
        // 生成顶点缓冲区
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertexData.count * MemoryLayout<GLfloat>.size, vertexData, GLenum(GL_STATIC_DRAW))
        
        glGenBuffers(1, &texCoordBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), texCoords.count * MemoryLayout<GLfloat>.size, texCoords, GLenum(GL_STATIC_DRAW))
        
        Gl2Utils.setIdentityMatrix(&matix)
        
        textureInfo.textureId = Gl2Utils.create2DTexture()
    }
    
    func onSurfaceChanged(screenWidth: Int, screenHeight: Int) {
        if self.screenWidth != screenWidth || self.screenHeight != screenHeight{
            self.screenWidth = screenWidth
            self.screenHeight = screenHeight
            
            if currentRegion.getWidth() == 0 || currentRegion.getHeight() == 0 {
                currentRegion = currentRegion.generateCoordinateRegion(left: 0, top: 0, width: screenWidth, height: screenHeight)
            }
            
            updateTexCord(coordinateRegion: currentRegion)
            glkView.setNeedsDisplay()
        }
        
    }
    
    func onDrawFrame() {
        Gl2Utils.checkGlError()
//        glViewport(0, 0, GLsizei(screenWidth), GLsizei(screenHeight))
        glUseProgram(shaderProgram)
        
        Gl2Utils.checkGlError()
        glUniformMatrix4fv(matrixHandle, 1, GLboolean(GL_FALSE), matix)
        
        Gl2Utils.checkGlError()
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertexData.count * MemoryLayout<GLfloat>.size, vertexData, GLenum(GL_STATIC_DRAW))
        
        
        Gl2Utils.checkGlError()
        
        glEnableVertexAttribArray(positionHandle)
        glVertexAttribPointer(positionHandle, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 3), nil)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        
        Gl2Utils.checkGlError()
        
        glEnableVertexAttribArray(texCoordHandle)
        glVertexAttribPointer(texCoordHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 2), nil)
        //BUFFER_OFFSET(MemoryLayout<GLfloat>.size * 3)
        
        Gl2Utils.checkGlError()
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), textureInfo.textureId)
        glUniform1i(uTextureHandle, 0)
        
        Gl2Utils.checkGlError()
        
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4)
        
        Gl2Utils.checkGlError()
        glDisableVertexAttribArray(positionHandle)
        glDisableVertexAttribArray(texCoordHandle)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER),  0)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        
        Gl2Utils.checkGlError()
    }
    
    func initCoordinate() {
        
    }
    
    func getVisibility() -> ITextureVisibility {
        return iTextureVisibility
    }
    
    func setVisibility(visibility: ITextureVisibility) {
        self.iTextureVisibility = visibility
    }
    
    func clearTexture(colorString: String) {
        
    }
    
    func release() {
        if vertexBuffer != 0 {
            glDeleteBuffers(1, &vertexBuffer)
        }
        
        if texCoordBuffer != 0 {
            glDeleteBuffers(1, &texCoordBuffer)
        }
        if textureInfo.textureId != 0 {
            glDeleteTextures(1, &(textureInfo.textureId))
        }
        
        if shaderProgram != 0{
            glDeleteProgram(shaderProgram)
        }
    }
    
    
    func updateTexCord(coordinateRegion: CoordinateRegion) {
        currentRegion = coordinateRegion
        let newVertices = currentRegion.getFloatArray(screenWidth: screenWidth, screenHeight: screenHeight)
        vertexData = newVertices
    }
    
    func updateTextureInfo(textureInfo: TextureInfo, isRecoverCord: Bool, iTextureVisibility: ITextureVisibility) {
        self.textureInfo = textureInfo
        self.iTextureVisibility = iTextureVisibility
        Matrix.setIdentityM(&matix, offset: 0)
        
        if (isRecoverCord) {
            currentRegion = CoordinateRegion().generateCoordinateRegion(
                left: 0.0, top: 0.0, width: screenWidth, height: screenHeight
            )
        }
        
        updateTexCord(coordinateRegion: currentRegion)
    }
    
    func updateTextureInfo(textureInfo: TextureInfo, isRecoverCord: Bool, backgroundColor: String?, iTextureVisibility: ITextureVisibility) {
        self.updateTextureInfo(textureInfo: textureInfo, isRecoverCord: isRecoverCord, iTextureVisibility: iTextureVisibility)
    }
    
    func getTextureInfo() -> TextureInfo {
        return textureInfo
    }
    
    func getScreenWidth() -> Int {
        return screenWidth
    }
    
    func getScreenHeight() -> Int {
        return screenHeight
    }
    
    func getTexCoordinateRegion() -> CoordinateRegion {
        return currentRegion
    }
    
}

