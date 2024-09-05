//
//  SignalStregth.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct SignalStrength:View {
    var active:Int = 2
    var scale: CGFloat = 50
    let width: CGFloat = 1
    let height: CGFloat = 1
    let cornerRadius: CGFloat = 0.4

    var body: some View {
        HStack(alignment: .bottom, spacing: 0.2*scale){
            ForEach(0..<5) { number in
                if(number<=active){
                    RoundedRectangle(cornerRadius: cornerRadius*scale)
                        .frame(width: scale*width, height: scale*height*CGFloat(number))
                    .foregroundColor(.white)
                }
                else{
                    RoundedRectangle(cornerRadius: cornerRadius*scale)
                        .frame(width: scale*width, height: scale*height*CGFloat(number))
                        .foregroundColor(Color(white: 0.3))
                }

            }
        }
    }
}
