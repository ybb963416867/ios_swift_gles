//
//  Matrix.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/20.
//

import simd

class Matrix {

    /// Computes an orthographic projection matrix.
    static func orthoM(m: inout [Float], offset: Int,
                       left: Float, right: Float,
                       bottom: Float, top: Float,
                       near: Float, far: Float) {
        guard left != right else { fatalError("left == right") }
        guard bottom != top else { fatalError("bottom == top") }
        guard near != far else { fatalError("near == far") }

        let rWidth = 1.0 / (right - left)
        let rHeight = 1.0 / (top - bottom)
        let rDepth = 1.0 / (far - near)

        let x = 2.0 * rWidth
        let y = 2.0 * rHeight
        let z = -2.0 * rDepth
        let tx = -(right + left) * rWidth
        let ty = -(top + bottom) * rHeight
        let tz = -(far + near) * rDepth

        m[offset + 0] = x
        m[offset + 5] = y
        m[offset + 10] = z
        m[offset + 12] = tx
        m[offset + 13] = ty
        m[offset + 14] = tz
        m[offset + 15] = 1.0

        for i in [1, 2, 3, 4, 6, 7, 8, 9, 11] {
            m[offset + i] = 0.0
        }
    }

    /// Multiplies two 4x4 matrices.
    static func multiplyMM(result: inout [Float], resultOffset: Int,
                           lhs: [Float], lhsOffset: Int,
                           rhs: [Float], rhsOffset: Int) {
        for i in 0..<4 {
            let rhsI0 = rhs[4 * i + rhsOffset]
            var ri0 = lhs[0 + lhsOffset] * rhsI0
            var ri1 = lhs[1 + lhsOffset] * rhsI0
            var ri2 = lhs[2 + lhsOffset] * rhsI0
            var ri3 = lhs[3 + lhsOffset] * rhsI0

            for j in 1..<4 {
                let rhsIJ = rhs[4 * i + j + rhsOffset]
                ri0 += lhs[4 * j + 0 + lhsOffset] * rhsIJ
                ri1 += lhs[4 * j + 1 + lhsOffset] * rhsIJ
                ri2 += lhs[4 * j + 2 + lhsOffset] * rhsIJ
                ri3 += lhs[4 * j + 3 + lhsOffset] * rhsIJ
            }

            result[4 * i + 0 + resultOffset] = ri0
            result[4 * i + 1 + resultOffset] = ri1
            result[4 * i + 2 + resultOffset] = ri2
            result[4 * i + 3 + resultOffset] = ri3
        }
    }

    /// Sets a matrix to the identity matrix.
    static func setIdentityM(_ m: inout [Float], offset: Int) {
        for i in 0..<16 {
            m[offset + i] = 0.0
        }
        for i in stride(from: 0, to: 16, by: 5) {
            m[offset + i] = 1.0
        }
    }

    /// Rotates a matrix by an angle (in degrees) around an axis (x, y, z).
    static func rotateM(m: inout [Float], offset: Int,
                        angle: Float, x: Float, y: Float, z: Float) {
        var tmp = [Float](repeating: 0.0, count: 16)
        setRotateM(rm: &tmp, offset: 0, angle: angle, x: x, y: y, z: z)
        multiplyMM(result: &m, resultOffset: offset, lhs: m, lhsOffset: offset, rhs: tmp, rhsOffset: 0)
    }

    /// Creates a rotation matrix.
    static func setRotateM(rm: inout [Float], offset: Int,
                           angle: Float, x: Float, y: Float, z: Float) {
        setIdentityM(&rm, offset: offset)
        let rad = angle * (Float.pi / 180.0)
        let s = sin(rad)
        let c = cos(rad)

        if x == 1.0 && y == 0.0 && z == 0.0 {
            rm[offset + 5] = c
            rm[offset + 6] = s
            rm[offset + 9] = -s
            rm[offset + 10] = c
        } else if x == 0.0 && y == 1.0 && z == 0.0 {
            rm[offset + 0] = c
            rm[offset + 8] = s
            rm[offset + 2] = -s
            rm[offset + 10] = c
        } else if x == 0.0 && y == 0.0 && z == 1.0 {
            rm[offset + 0] = c
            rm[offset + 1] = s
            rm[offset + 4] = -s
            rm[offset + 5] = c
        } else {
            let len = sqrt(x * x + y * y + z * z)
            guard len != 0 else { return }
            let recipLen = 1.0 / len
            let x = x * recipLen
            let y = y * recipLen
            let z = z * recipLen

            let nc = 1.0 - c
            let xy = x * y
            let yz = y * z
            let zx = z * x
            let xs = x * s
            let ys = y * s
            let zs = z * s

            rm[offset + 0] = x * x * nc + c
            rm[offset + 4] = xy * nc - zs
            rm[offset + 8] = zx * nc + ys
            rm[offset + 1] = xy * nc + zs
            rm[offset + 5] = y * y * nc + c
            rm[offset + 9] = yz * nc - xs
            rm[offset + 2] = zx * nc - ys
            rm[offset + 6] = yz * nc + xs
            rm[offset + 10] = z * z * nc + c
        }
    }
    
    static func translateM(m: inout [Float], offset: Int, x: Float, y: Float, z: Float) {
        for i in 0..<4 {
            let mi = offset + i
            m[12 + mi] += m[mi] * x + m[4 + mi] * y + m[8 + mi] * z
        }
    }
    
    static func length(_ x: Float, _ y: Float, _ z: Float) -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    static func setLookAtM(rm: inout [Float], offset: Int,
                           eyeX: Float, eyeY: Float, eyeZ: Float,
                           centerX: Float, centerY: Float, centerZ: Float,
                           upX: Float, upY: Float, upZ: Float) {
        // 计算 f (视线方向向量)
        var fx = centerX - eyeX
        var fy = centerY - eyeY
        var fz = centerZ - eyeZ

        // 归一化 f
        let rlf = 1.0 / length(fx, fy, fz)
        fx *= rlf
        fy *= rlf
        fz *= rlf

        // 计算 s = f x up (叉积)
        var sx = fy * upZ - fz * upY
        var sy = fz * upX - fx * upZ
        var sz = fx * upY - fy * upX

        // 归一化 s
        let rls = 1.0 / length(sx, sy, sz)
        sx *= rls
        sy *= rls
        sz *= rls

        // 计算 u = s x f
        let ux = sy * fz - sz * fy
        let uy = sz * fx - sx * fz
        let uz = sx * fy - sy * fx

        // 设置视图矩阵
        rm[offset + 0] = sx
        rm[offset + 1] = ux
        rm[offset + 2] = -fx
        rm[offset + 3] = 0.0

        rm[offset + 4] = sy
        rm[offset + 5] = uy
        rm[offset + 6] = -fy
        rm[offset + 7] = 0.0

        rm[offset + 8] = sz
        rm[offset + 9] = uz
        rm[offset + 10] = -fz
        rm[offset + 11] = 0.0

        rm[offset + 12] = 0.0
        rm[offset + 13] = 0.0
        rm[offset + 14] = 0.0
        rm[offset + 15] = 1.0

        // 平移矩阵
        translateM(m: &rm, offset: offset, x: -eyeX, y: -eyeY, z: -eyeZ)
    }


}

