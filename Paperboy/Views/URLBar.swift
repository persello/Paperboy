//
//  URLBar.swift
//  Paperboy
//
//  Created by Riccardo Persello on 23/12/22.
//

import SwiftUI

struct URLBar: View {
    var url: URL
    @Binding var progress: Double
    
    private var visible: Bool {
        return progress < 0.99
    }
    
    private var title: String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.host ?? ""
    }
    
    var body: some View {
        VStack {
            Text("\(title)")
                .truncationMode(.tail)
                .lineLimit(1)
                .frame(idealWidth: 300)
                .padding(.top, 4)
                .padding(.bottom, -6)
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .padding(.vertical, -8)
                .padding(.horizontal, -4)
                .opacity(visible ? 1 : 0)
                .animation(.linear, value: visible)
                .frame(height: 4)
                .clipped()
        }
            .background(.foreground.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct URLBar_Previews: PreviewProvider {
    static var previews: some View {
        URLBar(url: URL(string: "https://apple.com")!, progress: .constant(1))
    }
}
