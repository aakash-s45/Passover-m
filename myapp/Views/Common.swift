//
//  Common.swift
//  myapp
//
//  Created by Aakash Solanki on 03/09/24.
//

import SwiftUI

struct Divider:View {
    let height: CGFloat
    let width: CGFloat
    let color: Color
    var body: some View {
        Rectangle()
            .frame(width: width, height: height)
            .foregroundColor(color)
    }
}
