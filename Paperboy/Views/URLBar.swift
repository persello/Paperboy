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
        return components?.host ?? "Paperboy"
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            VStack {
                Text("\(title)")
                    .truncationMode(.tail)
                    .lineLimit(1)
                    .frame(idealWidth: 300)
                    .padding(.top, 4)
                    .padding(.bottom, -6)
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                #if os(macOS)
                    .padding(.vertical, -8)
                    .padding(.horizontal, -4)
                #endif
                    .opacity(visible ? 1 : 0)
                    .animation(.linear, value: visible)
                    .frame(height: 4)
                    .clipped()
            }
            .background(.foreground.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Link(destination: url) {
                Label("Open in Safari", systemSymbol: .safari)
                    .labelStyle(.iconOnly)
            }
            .foregroundColor(.secondary)
            .padding(.trailing, 8)
        }
    }
}


struct URLBar_Previews: PreviewProvider {
    static var previews: some View {
        URLBar(url: URL(string: "https://apple.com")!, progress: .constant(0.5))
            .previewLayout(.sizeThatFits)
    }
}
