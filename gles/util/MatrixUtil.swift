//
//  MatrixUtil.swift
//  swift_gles
//
//  Created by yangbinbing on 2025/1/18.
//

import GLKit

enum  PositionType {
    case CENTER
    case LEFT_TOP
    case RIGHT_TOP
    case LEFT_BOTTOM
    case RIGHT_BOTTOM
    case MIDDLE_TOP
    case MIDDLE_BOTTOM
}

struct MatrixUtil {
    
    static func screenToGlCoordinate(px: Float, py: Float, screenWidth width: Int, screenHeight height: Int, xBoundary xb: Float = 1.0, yBoundary yb: Float = 1.0) -> [Float]{
        let vx = (px / width.toFloat()) * xb * 2.0 - xb // 转换 X 坐标
        let vy = yb - (py / height.toFloat()) * yb * 2.0 // 转换 Y 坐标并反转 Y 轴
        
        return [vx, vy]
    }
    
    static func screenToGlCoordinateX(px: Float, screenWidth width: Float, xBoundary xb: Float = 1.0) -> Float {
        return (px / width) * 2.0 * xb - 1.0 * xb
    }
    
    static func screenToGlCoordinateY(py: Float, screenHeight height : Float, yBoundary yb: Float = 1.0) -> Float {
        return (1.0 - (py / height) * 2.0) * yb
    }
    
    
    static func getPicOriginMatrix(matrix: inout [Float], imgWidth: Int, imgHeight: Int, viewWidth: Int, viewHeight: Int,surfaceWidth: Int, surfaceHeight: Int, coordinateRegion: CoordinateRegion, type: PositionType){
        if (imgHeight <= 0 || imgWidth <= 0 || viewWidth <= 0 || viewHeight <= 0 || surfaceWidth <= 0 || surfaceHeight <= 0) {
            return
        }
        
        let originArea = coordinateRegion.getSurfaceArea(surfaceWidth: surfaceWidth, surfaceHeight: surfaceHeight)
        
        var oLeft: Float = 0.0
        var oRight: Float = 0.0
        var oTop: Float = 0.0
        var oBottom: Float = 0.0
        
        let viewAspectRatio = viewWidth.toFloat() / viewHeight.toFloat()
        let bitmapAspectRatio = imgWidth.toFloat() / imgHeight.toFloat()
        
        
        var projection:[Float] = Array(repeating: 0.0, count: 16)
        var  mViewMatrix:[Float] = Array(repeating: 0.0, count: 16)
        
        if bitmapAspectRatio > viewAspectRatio {
            oLeft = -1.0
            oRight = 1.0
            oTop = bitmapAspectRatio / viewAspectRatio
            oBottom = -bitmapAspectRatio / viewAspectRatio
            
            Matrix.orthoM(m: &projection, offset: 0, left: oLeft, right: oRight, bottom: oBottom, top: oTop, near: 1.0, far: 3.0)
        } else {
            oLeft = -viewAspectRatio / bitmapAspectRatio
            oRight = viewAspectRatio / bitmapAspectRatio
            oTop = 1
            oBottom = -1
            Matrix.orthoM(m: &projection, offset: 0, left: oLeft, right: oRight, bottom: oBottom, top: oTop, near: 1.0, far: 3.0)
        }
        
        Matrix.setLookAtM(
            rm: &mViewMatrix, offset: 0,
            eyeX: (originArea.coordinateLeft + originArea.coordinateRight) / 2.0,
            eyeY: (originArea.coordinateBottom + originArea.coordinateTop) / 2.0, eyeZ: 1.0,
            centerX: (originArea.coordinateLeft + originArea.coordinateRight) / 2.0,
            centerY: (originArea.coordinateBottom + originArea.coordinateTop) / 2.0, centerZ: 0.0, upX: 0.0, upY: 1.0, upZ: 0.0
        )
        
        let matrixOriginArea = coordinateRegion.getSurfaceArea(surfaceWidth: surfaceWidth, surfaceHeight: surfaceHeight, xBoundary: abs(oRight - oLeft) / 2, yBoundary: abs(oTop - oBottom) / 2)
        
        Matrix.multiplyMM(result: &matrix, resultOffset: 0, lhs: projection, lhsOffset: 0, rhs: mViewMatrix, rhsOffset: 0)
        
        var difWidth: Float = 0.0
        var difHeight: Float = 0.0
        if (bitmapAspectRatio > viewAspectRatio) {
            let originHeight = coordinateRegion.getWidth()/(bitmapAspectRatio)
            
            difHeight = abs(
                MatrixUtil.screenToGlCoordinateY(py: originHeight, screenHeight: surfaceHeight.toFloat(), yBoundary: abs(oTop - oBottom) / 2.0) - MatrixUtil.screenToGlCoordinateY(py: coordinateRegion.getHeight(), screenHeight: surfaceHeight.toFloat(), yBoundary: abs(oTop - oBottom) / 2.0)
            )
            
        } else {
            let originWidth = coordinateRegion.getHeight() * (bitmapAspectRatio)
            
            difWidth = abs(
                MatrixUtil.screenToGlCoordinateX(px: originWidth, screenWidth: surfaceWidth.toFloat(), xBoundary: abs(oLeft - oRight) / 2) - MatrixUtil.screenToGlCoordinateX(px: coordinateRegion.getWidth(), screenWidth: surfaceWidth.toFloat(), xBoundary: abs(oLeft - oRight) / 2)
            )
        }
        
        
        switch type {
        case .CENTER :
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0, z: 0)
            
        case .LEFT_TOP:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0 - difWidth / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2 + difHeight / 2.0, z: 0)
            
        case .RIGHT_TOP:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0 + difWidth / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0 + difHeight / 2.0, z: 0)
        case .LEFT_BOTTOM:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0 - difWidth / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0 - difHeight / 2.0, z: 0)
            
        case .RIGHT_BOTTOM:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0 + difWidth / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0 - difHeight / 2.0, z: 0.0)
        case .MIDDLE_TOP:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0 + difHeight / 2.0, z: 0)
            
        case .MIDDLE_BOTTOM:
            Matrix.translateM(m: &matrix, offset: 0, x: (matrixOriginArea.coordinateRight + matrixOriginArea.coordinateLeft) / 2.0, y: (matrixOriginArea.coordinateTop + matrixOriginArea.coordinateBottom) / 2.0 - difHeight / 2.0, z: 0)
        }
    }
}

