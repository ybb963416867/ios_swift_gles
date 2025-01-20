//
//  shaderf.fsh
//  OpenGLES-绘图
//
//  Created by zhangxin on 2022/2/23.
//  片远着色器 Fragment Shader(片元着色器) 
//  片元着色器的作用是处理由光栅化阶段生成的每个片元，最终计算出每个像素的最终颜色

// 纹理坐标

precision mediump float;
varying lowp vec2 aCoord;
// 采样器
uniform sampler2D vTexture;
// 着色器程序(Shader program)
void main() {
    lowp vec2 textCoord = aCoord;
    // 读取纹素(纹理的颜色)放到输出变量gl_FragColor上
    gl_FragColor = texture2D(vTexture, textCoord);
}
