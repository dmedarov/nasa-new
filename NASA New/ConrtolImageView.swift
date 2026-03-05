//
//  ControlImageView.swift
//  Pinch (iOS)
//
//  Created by Damian Medarov on 5.02.22.
//

import SwiftUI

struct ControlImageView: View {
    @AppStorage("isDarkMode") private var isDarkmode: Bool = true
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 30))
            .foregroundColor(isDarkmode ? Color(UIColor.white) : Color(UIColor.systemIndigo))
    }
}

struct ControlImageView_Previews: PreviewProvider {
    static var previews: some View {
        ControlImageView(icon: "minus.magnifyingglass")
           // .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
            
    }
}

