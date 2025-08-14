//
//  ContentView.swift
//  swift_gles
//
//  Created by yunshen on 2025/1/16.
//

import SwiftUI
import gles

struct ContentView: View {
    var body: some View {
//        SurfaceViewContent()
        NavigationStack{
            ScrollView {
                Rectangle().fill(Color(Color.white)).ignoresSafeArea()
                
                VStack {
                    NavigationLink(destination: GLKViewControllerWrapper()) {
                        Text("opgl 使用")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: GLKViewControllerWrapper1()) {
                        Text("opgl 显示图片")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: YSGSImageViewWrapper()) {
                        Text("动态加载")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: SurfaceViewContent()) {
                        Text("抽离")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: CaptrueView()) {
                        Text("截图")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    
                }
                
                
            }
            .padding()
        
        }
        
    }
}

#Preview {
    ContentView()
}
