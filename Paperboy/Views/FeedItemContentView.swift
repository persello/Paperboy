//
//  FeedItemContentView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedItemContentView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .toolbar {
                Button {
                    
                } label: {
                    Label("Antani", systemImage: "square.and.arrow.up")
                }
            }
    }
}

struct FeedItemContentView_Previews: PreviewProvider {
    static var previews: some View {
        FeedItemContentView()
    }
}
