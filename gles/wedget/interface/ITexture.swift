//
//  ITexture.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/18.
//

enum ITextureVisibility {
    case VISIBLE
    case INVISIBLE
}

protocol ITexture{
    func onSurfaceCreated()
    func onSurfaceChanged(screenWidth: Int, screenHeight: Int)
    func onDrawFrame()
    func initCoordinate()
    func getVisibility() -> ITextureVisibility
    func setVisibility(visibility: ITextureVisibility)
    func clearTexture(colorString: String)
    func release()
}

protocol IBaseTexture: ITexture {
    func updateTexCord(coordinateRegion: CoordinateRegion)
    func updateTextureInfo(
        textureInfo: TextureInfo,
        isRecoverCord: Bool,
        iTextureVisibility: ITextureVisibility
    )
    
    func updateTextureInfo(
        textureInfo: TextureInfo,
        isRecoverCord: Bool,
        backgroundColor: String?,
        iTextureVisibility: ITextureVisibility
    )
    
    func getTextureInfo() -> TextureInfo
    func getScreenWidth() -> Int
    func getScreenHeight() -> Int
    func getTexCoordinateRegion() -> CoordinateRegion
}

