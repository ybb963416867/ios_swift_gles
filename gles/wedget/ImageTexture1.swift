//
//  ImageTexture.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/18.
//

class ImageTexture1: BaseTexture {
    override func updateTexCord(coordinateRegion: CoordinateRegion) {
        super.updateTexCord(coordinateRegion: coordinateRegion)
        
//        MatrixUtil.getPicOriginMatrix(matrix: &matix, imgWidth: getTextureInfo().width, imgHeight: getTextureInfo().height, viewWidth: coordinateRegion.getWidth().toInt(), viewHeight: coordinateRegion.getHeight().toInt(), surfaceWidth: getScreenWidth(), surfaceHeight: getScreenHeight(), coordinateRegion: coordinateRegion, type: PositionType.LEFT_BOTTOM)
        
//        print("ImageTexture cord = \(getTexCoordinateRegion()) \n")
    }
}

