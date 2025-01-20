//
//  IRender.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/18.
//

import GLKit

protocol IRender {
    func onSurfaceCreate(context : EAGLContext)
    func onSurfaceChanged(width: Int, height: Int)
    func onDrawFrame()
    func release()
}

