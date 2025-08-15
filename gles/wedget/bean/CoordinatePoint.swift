//
//  CoordinatePoint.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/18.
//

import GLKit

struct CoordinatePoint{
    var x: Float = 0
    var y: Float = 0
    var c: Float = 0
}

extension CoordinatePoint {
    public func toFloatSize( screenWidth: Int,
                             screenHeight: Int) -> Triple<Float, Float, Float>{
        let screenToGlCoordinate = MatrixUtil.screenToGlCoordinate(px: x, py: y, screenWidth: screenWidth, screenHeight: screenHeight)
        
        return Triple(first: screenToGlCoordinate[0], second: screenToGlCoordinate[1], third: c)
    }
}

struct TextureInfo{
    var textureId: GLuint = 0
    var width: Int = 0
    var height: Int = 0
}

extension TextureInfo{
    public func generateBitmapTexture(cgImage image: CGImage) -> TextureInfo {
        
        var newInstance = self
        if newInstance.textureId == 0 {
            newInstance.textureId = Gl2Utils.create2DTexture()
        }
        
        let result = Gl2Utils.createTexture(cgImage: image, texture: newInstance.textureId)
        
        newInstance.textureId = result.first
        newInstance.width = result.second
        newInstance.height = result.third
        return newInstance
    }
    
    public func generaTextureFromView(_ view: UIView, frame: CGRect) -> TextureInfo {
        var newInstance = self
        if newInstance.textureId == 0 {
            newInstance.textureId = Gl2Utils.create2DTexture()
        }
        let result = Gl2Utils.createTextureFromView(view, frame: frame, texture: newInstance.textureId)
        newInstance.textureId = result.first
        newInstance.width = result.second
        newInstance.height = result.third
        return newInstance
    }
    
    public func generaTextureFromView(_ view: UIView) -> TextureInfo {
        var newInstance = self
        if newInstance.textureId == 0 {
            newInstance.textureId = Gl2Utils.create2DTexture()
        }
        let result = Gl2Utils.createTextureFromView(view, texture: newInstance.textureId)
        newInstance.textureId = result.first
        newInstance.width = result.second
        newInstance.height = result.third
        return newInstance
    }
}


struct CoordinateRegion{
    var leftTop: CoordinatePoint = CoordinatePoint()
    var rightTop: CoordinatePoint = CoordinatePoint()
    var leftBottom: CoordinatePoint = CoordinatePoint()
    var rightBottom: CoordinatePoint = CoordinatePoint()
}

extension CoordinateRegion {
    public func generateCoordinateRegion(left: Float, top: Float, width: Int, height: Int) -> CoordinateRegion {
        var region = self
        region.leftTop.x = left
        region.leftTop.y = top
        region.rightTop.x = left + Float(width)
        region.rightTop.y = top
        region.leftBottom.x = left
        region.leftBottom.y = top + Float(height)
        region.rightBottom.x = left + Float(width)
        region.rightBottom.y = top + Float(height)
        
        return region.check()
    }
    
    public func check() -> CoordinateRegion {
        
        if (leftTop.x != leftBottom.x || rightTop.x != rightBottom.x || leftTop.y != rightTop.y || leftBottom.y != rightBottom.y) {
            fatalError("oordinateRegion Argument is error")
        }
        return self
    }
    
    
    public func getSurfaceArea(surfaceWidth width : Int, surfaceHeight height : Int, xBoundary xb: Float = 1.0, yBoundary yb : Float = 1.0)  -> CoordinateArea {
        let result = self.check()
        let lTSurfacePoint = MatrixUtil.screenToGlCoordinate(px: result.leftTop.x, py: result.leftTop.y, screenWidth: width, screenHeight: height, xBoundary: xb, yBoundary: yb)
        
        let rBSurfacePoint = MatrixUtil.screenToGlCoordinate(px: result.rightBottom.x, py: result.rightBottom.y, screenWidth: width, screenHeight: height, xBoundary: xb, yBoundary: yb)
        
        return CoordinateArea(coordinateLeft: lTSurfacePoint[0], coordinateTop:  lTSurfacePoint[1], coordinateRight: rBSurfacePoint[0], coordinateBottom: rBSurfacePoint[1])
    }
    
    public func getWidth() ->Float {
        return abs(leftTop.x - rightTop.x)
    }
    
    public func getHeight() -> Float {
        return abs(leftTop.y - leftBottom.y)
    }
    
    public func getFloatArray(screenWidth: Int, screenHeight: Int) -> [Float]{
        let lt = leftTop.toFloatSize(screenWidth: screenWidth, screenHeight: screenHeight)
        let lb = leftBottom.toFloatSize(screenWidth: screenWidth, screenHeight: screenHeight)
        let rt = rightTop.toFloatSize(screenWidth: screenWidth, screenHeight: screenHeight)
        let rb = rightBottom.toFloatSize(screenWidth: screenWidth, screenHeight: screenHeight)
        
        return [lt.first, lt.second, lt.third,
                lb.first, lb.second, lb.third,
                rb.first, rb.second, rb.third,
                rt.first, rt.second, rt.third]
        
    }
    
}

struct CoordinateArea{
    var coordinateLeft: Float = 0.0
    var coordinateTop: Float = 0.0
    var coordinateRight: Float = 0.0
    var coordinateBottom: Float = 0.0
}

extension CoordinateArea {
    
}
