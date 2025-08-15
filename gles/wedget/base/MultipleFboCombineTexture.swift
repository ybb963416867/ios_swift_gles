//
//  MultipleFboCombineTexture.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/21.
//

import GLKit

class MultipleFboCombineTexture : IBaseFboCombineTexture{
    
    private var numFbo: Int
    private var glkView: GLKView
    private var vertPath: String
    private var fragPath: String
    
    
    private var combinedProjectionMatrix : [GLfloat] = Array(repeating: 0.0, count: 16)
    private var fbo:[GLuint]!
    private var combinedTexture:[GLuint]!
    private var screenWidth = 0
    private var screenHeight = 0
    
    private var shaderProgram: GLuint = GLuint()
    private var texCoordHandle: GLuint = GLuint()
    private var positionHandle: GLuint = GLuint()
    private var uTextureHandle: Int32 = 0
    private var matrixHandle: Int32 = 0
    
    private var vertexBuffer = GLuint()
    private var texCoordBuffer = GLuint()
    
    private var texCoords : [Float] = [
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0
    ]
    
    private var vertexData: [Float] = [
        -1, 1, 0.0,  // 左上角
         -1, -1, 0.0,  // 左下角
         1, -1, 0.0,  // 右下角
         1, 1, 0.0 // 右上角
    ]
    
    init(numFbo: Int, glkView: GLKView, vertPath: String, fragPath: String) {
        self.numFbo = numFbo
        self.vertPath = vertPath
        self.fragPath = fragPath
        self.glkView = glkView
    }
    
    func onSurfaceCreated(screenWidth: Int, screenHeight: Int) {
        
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        
        fbo = Array(repeating: 0, count: numFbo)
        combinedTexture = Array(repeating: 0, count: numFbo)
        
        let bundlePath = Bundle(for: MultipleFboCombineTexture.self).path(forResource: "gles", ofType: "bundle")!
        
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
        
        Gl2Utils.setIdentityMatrix(&combinedProjectionMatrix)
        
        fbo.withUnsafeMutableBufferPointer{ fboBuffer in
            glGenFramebuffers(GLsizei(fboBuffer.count), fboBuffer.baseAddress)
        }
        
        combinedTexture.withUnsafeMutableBufferPointer{ texture in
            glGenTextures(GLsizei(texture.count), texture.baseAddress)
        }
        
        for index in 0..<numFbo {
            glBindTexture(GLenum(GL_TEXTURE_2D), combinedTexture[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA ,GLsizei(screenWidth) , GLsizei(screenHeight), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
            
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_NEAREST))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_LINEAR))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
            
            
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo[index])
            
            glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), combinedTexture[index], 0)
            
            let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
            
            if status != GLenum(GL_FRAMEBUFFER_COMPLETE){
                print("Framebuffer incomplete: \(status) index = \(index) screenWidth = \(screenWidth) screenHeight = \(screenHeight) texture = \(combinedTexture[index])  fbo = \(fbo[index])")
            }
            
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            glBindTexture(GLenum(GL_TEXTURE_2D), 0)
            
        }
        
        Gl2Utils.checkGlError()
    }
    
    func onSurfaceChanged(screenWidth: Int, screenHeight: Int) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight

        for element in combinedTexture {
            glBindTexture(GLenum(GL_TEXTURE_2D), element)
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA,GLsizei(screenWidth) , GLsizei(screenHeight), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
        }

        Matrix.setIdentityM(&combinedProjectionMatrix, offset: 0)
        glViewport(0, 0, GLsizei(screenWidth) , GLsizei(screenHeight))
        Gl2Utils.checkGlError()
    }
    
    func onDrawFrame(textureIdIndex: Int) {
        if textureIdIndex >= numFbo {
            fatalError("")
        }
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        glkView.bindDrawable()
        Gl2Utils.checkGlError()
        
        glUseProgram(shaderProgram)
        
        Gl2Utils.checkGlError()
        glUniformMatrix4fv(matrixHandle, 1, GLboolean(GL_FALSE), combinedProjectionMatrix)
        
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
        glBindTexture(GLenum(GL_TEXTURE_2D), combinedTexture[textureIdIndex])
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
    
    func getTextureArray() -> [GLuint] {
        return combinedTexture
    }
    
    func getScreenWidth() -> Int {
        return screenWidth
    }
    
    func getScreenHeight() -> Int {
        return screenHeight
    }
    
    func getFboFrameBuffer() -> [GLuint] {
        return fbo
    }
    
    
    
    func release() {
        combinedTexture.withUnsafeMutableBufferPointer{ textureList in
            glDeleteTextures(GLsizei(textureList.count), textureList.baseAddress)
        }
        
        fbo.withUnsafeMutableBufferPointer{ fboList in
            glDeleteFramebuffers(GLsizei(fboList.count), fboList.baseAddress)
        }
        
        if shaderProgram != 0 {
            glDeleteProgram(shaderProgram)
        }
        
    }
    
    
}
