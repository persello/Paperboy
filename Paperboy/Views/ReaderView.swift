//
//  ReaderView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 21/12/22.
//

import SwiftUI
import SwiftUIWKWebView

struct ReaderView: View {
    @Binding var feedItem: FeedItemModel?
    
    @State private var url: URL
    @State private var loadingProgress: Double = 0
    
    init(feedItem: Binding<FeedItemModel?>) {
        self._feedItem = feedItem
        self._url = State(initialValue: feedItem.wrappedValue?.url ?? URL(string: "https://")!)
    }
    
    var body: some View {
#if os(macOS)
        if self.feedItem != nil {
            MacWebView(url: $url, loadingProgress: $loadingProgress)
                .toolbar {
                    Spacer()
                    URLBar(url: url, progress: $loadingProgress)
                    Spacer()
                }
                .onChange(of: feedItem) { newValue in
                    if let url = feedItem?.url {
                        self.url = url
                    }
                }
        }
#endif
    }
}

struct ReaderView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderView(feedItem: .constant(FeedItemModel()))
    }
}
