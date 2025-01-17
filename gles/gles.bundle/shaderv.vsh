//
//  shaderv.vsh
//  OpenGLES-绘图
//
//  Created by zhangxin on 2022/2/23.
//  定点着色器  Vertex Shader(顶点着色器)
//顶点着色器分为输入和输出两部分,负责的功能是把输入的数据进行矩阵变换位置,计算光照公式生成逐顶点颜⾊,⽣成/变换纹理坐标.并且把位置和纹理坐标这样的参数发送到片段着色器.

//位置属性
attribute vec4 vPosition;
//坐标属性
attribute vec2 vCoord;
//输出变量
varying lowp vec2 aCoord;

//着色器城西（shader program）
void main() {
    //赋值坐标属性到输出变量
    aCoord = vCoord;
    // 赋值位置到内建变量gl_Position上，作为输出信息（必须）
    gl_Position = vPosition;
}
