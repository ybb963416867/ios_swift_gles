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
    
}

@inline(__always)
func check(value: Bool, lazyMessage: () -> Any){
    guard value else {
        let message = lazyMessage()
        fatalError("\(message)")
    }
}


