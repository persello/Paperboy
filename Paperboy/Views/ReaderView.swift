//
//  ReaderView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 21/12/22.
//

import SwiftUI
import SFSafeSymbols
import FeedKit

struct ReaderView: View {
    @Environment(\.managedObjectContext) private var context
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    
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
                    Text("Error")
                        .font(.title)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                    Button {
                        self.error = nil
                    } label: {
                        Text("Reload")
                    }
                }
                .padding()
            } else {
                Group {
#if os(macOS)
                    MacWebView(url: $url, loadingProgress: $loadingProgress, error: $error)
#elseif os(iOS)
                    Group {
                        if sizeClass == .regular {
                            // iPad
                            iOSRegularWebView(url: $url, loadingProgress: $loadingProgress, error: $error)
                        } else {
                            // iPhone
                            iOSRegularWebView(url: $url, loadingProgress: $loadingProgress, error: $error)
                                .navigationBarTitle(url.host() ?? "")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            
                            Button {
                                
                            } label: {
                                Label("Previous article", systemSymbol: .chevronUp)
                            }
                            
                            Button {
                                
                            } label: {
                                Label("Next article", systemSymbol: .chevronDown)
                            }
                        }
                    }
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
            #if os(macOS)
            URLBar(url: url, progress: $loadingProgress)
            #endif
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
        let feed = try! FeedKit.FeedParser(URL: URL(string: "https://9to5mac.com/feed")!).parse().get().rssFeed
        let item = FeedItemModel(from: feed!.items!.first!, context: context)
        
        return NavigationStack {
            ReaderView(feedItem: item)
        }
    }
}
