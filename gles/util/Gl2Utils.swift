//
//  Gl2Utils.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/16.
//

import GLKit

struct Gl2Utils {
    static func loadProgram(vSource: String, fSource: String) -> GLuint {
        var programe = GLuint()
        programe = glCreateProgram()
        
        let vertexShader = compileShader(type: GLenum(GL_VERTEX_SHADER), shaderString: vSource)
        
        let fragmentShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), shaderString: fSource)
        
        glAttachShader(programe, vertexShader)
        glAttachShader(programe, fragmentShader)
        glLinkProgram(programe)
        
        var programeStatus : GLint = 0
        glGetProgramiv(programe, GLenum(GL_LINK_STATUS), &programeStatus)
        
        check(value: programeStatus == GL_TRUE){
            getProgramLinkLog(program: programe)
        }
        
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        
        return programe
    }
    
    
    static func loadBundleFile(bundlePath: String, forResource name: String, ofType ext : String) -> String {
        guard let path = Bundle(path: bundlePath)?.path(forResource: name, ofType: ext) else {
            fatalError("loadBundleFile error")
        }
        return try! String(contentsOfFile: path, encoding: .utf8)
    }
    
    static func compileShader(type: GLenum, shaderString: String) -> GLuint {
        var shader : GLuint = 0
        shaderString.withCString(){ pointer in
            var source: UnsafePointer<GLchar>? = pointer
            shader = glCreateShader(type)
            glShaderSource(shader, 1, &source, nil)
            glCompileShader(shader)
        }
        
        var compileShaderStatus = GLint()
        
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileShaderStatus)
        
        check(value: compileShaderStatus == GL_TRUE){
            Gl2Utils.getShaderCompileLog(shader: shader)
        }
        
        return shader
        
    }
    static func getShaderCompileLog(shader: GLuint) -> String {
        var logLength: GLint = 0;
        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            let log = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
            defer {log.deallocate()}
            glGetShaderInfoLog(shader, logLength, nil, log)
            return String(cString: log)
        } else {
            return "No compile log available. \(shader)"
        }
    }
    
    static func getProgramLinkLog(program: GLuint) -> String {
        var logLength: GLint = 0
        glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        
        if logLength > 0 {
            let log = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
            
            defer{
                log.deallocate()
            }
            
            glGetProgramInfoLog(program, logLength, nil, log)
            return String(cString: log)
        }
        return "No program log available."
    }
    
    /// 将图片 转为纹理
    static  func createTexture(cgImage image: CGImage) -> Triple<GLuint, Int, Int> {
        let width = image.width
        let height = image.height
        let spriteData = calloc(width * height * 4, MemoryLayout<GLubyte>.size)
        defer { free(spriteData) }
        
        let spriteContext = CGContext(data: spriteData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: image.colorSpace!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        //        spriteContext?.translateBy(x: 0, y: CGFloat(height))
        //        spriteContext?.scaleBy(x: 1.0, y: -1.0)
        spriteContext?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var texture: GLuint = 0
        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(width), GLsizei(height), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), spriteData)
        
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_NEAREST))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_LINEAR))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        
        return Triple(first: texture, second: width, third: height)
    }
    
    /// 将图片 转为纹理
    static  func createTexture(cgImage image: CGImage, texture: GLuint) -> Triple<GLuint, Int, Int> {
        let width = image.width
        let height = image.height
        let spriteData = calloc(width * height * 4, MemoryLayout<GLubyte>.size)
        defer { free(spriteData) }
        
        let spriteContext = CGContext(data: spriteData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: image.colorSpace!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        //        spriteContext?.translateBy(x: 0, y: CGFloat(height))
        //        spriteContext?.scaleBy(x: 1.0, y: -1.0)
        spriteContext?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        if texture == 0 {
            var texture: GLuint = 0
            glGenTextures(1, &texture)
        }
        
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(width), GLsizei(height), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), spriteData)
        
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_NEAREST))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_LINEAR))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        
        return Triple(first: texture, second: width, third: height)
    }
    
    static func create2DTexture() -> GLuint {
        var texture: GLuint = 0
        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_NEAREST))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_LINEAR))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        return texture
    }
    
    ///初始化矩阵
    static func setIdentityMatrix(_ sm: inout [Float], offset: Int = 0) {
        // Ensure the matrix has at least 16 elements
        guard sm.count >= offset + 16 else {
            fatalError("Matrix must have at least 16 elements.")
        }
        
        // Initialize all elements to 0
        for i in 0..<16 {
            sm[offset + i] = 0.0
        }
        
        // Set diagonal elements to 1.0
        for i in stride(from: 0, to: 16, by: 5) {
            sm[offset + i] = 1.0
        }
    }
    
    
}

@inline(__always)
func check(value: Bool, lazyMessage: () -> Any){
    guard value else {
        let message = lazyMessage()
        fatalError("\(message)")
    }
}

struct Triple<A, B, C>{
    let first: A
    let second: B
    let third: C
}

extension Int {
    func toFloat() -> Float {
        return Float(self)
    }
}

extension Float {
    func toInt() -> Int{
        return Int(self)
    }
}


