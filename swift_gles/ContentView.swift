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
                }
                
                
            }
            .padding()
        }
        
    }
}

#Preview {
    ContentView()
}
