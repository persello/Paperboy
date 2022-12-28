//
//  ReaderView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 21/12/22.
//

import SwiftUI

struct ReaderView: View {
    @Environment(\.managedObjectContext) private var context
    
    @State private var url: URL
    @State private var loadingProgress: Double = 0
    @State private var error: Error?
    
    @ObservedObject private var feedItem: FeedItemModel
    
    init(feedItem: FeedItemModel) {
        self._url = State(initialValue: feedItem.url ?? URL(string: "https://apple.com")!)
        self.feedItem = feedItem
    }
    
    var body: some View {
        Group {
            if let error {
                VStack {
                    Text(error.localizedDescription)
                        .font(.title)
                    Button {
                        self.error = nil
                    } label: {
                        Text("Reload")
                    }
                }
            } else {
                Group {
#if os(macOS)
                    MacWebView(url: $url, loadingProgress: $loadingProgress, error: $error)
#elseif os(iOS)
                    iOSWebView(url: $url, loadingProgress: $loadingProgress, error: $error)
#endif
                }
                .onChange(of: loadingProgress) { newValue in
                    if newValue == 1.0 {
                        self.feedItem.read = true
                        
                        // TODO: Error management.
                        try? context.save()
                    }
                }
            }
        }
        .toolbar {
            Spacer()
            URLBar(url: url, progress: $loadingProgress)
            Spacer()
        }
        .onChange(of: feedItem) { newValue in
            if let url = newValue.url {
                self.url = url
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
}

struct ReaderView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let item = FeedItemModel(context: context)
        
        return NavigationStack {
            ReaderView(feedItem: item)
        }
    }
}
