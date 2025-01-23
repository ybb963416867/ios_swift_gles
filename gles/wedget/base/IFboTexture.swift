//
//  IFboTexture.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/21.
//

import GLKit

protocol IFboTexture{
    func onSurfaceCreated(screenWidth: Int, screenHeight: Int)
    func onSurfaceChanged(screenWidth: Int, screenHeight: Int)
    func onDrawFrame(textureIdIndex: Int)
    func release()
}

protocol IBaseFboCombineTexture : IFboTexture{
    func getTextureArray() -> [GLuint]
    func getScreenWidth() -> Int
    func getScreenHeight() -> Int
    func getFboFrameBuffer() -> [GLuint]
}


