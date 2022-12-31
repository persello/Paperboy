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
    
    @Binding private var feedItem: FeedItemModel?
    
    private var itemList: [FeedItemModel]?
    
    private var nextItem: FeedItemModel? {
        guard let feedItem else { return nil }
        guard let currentIndex = itemList?.firstIndex(of: feedItem) else { return nil }
        let nextIndex = itemList?.index(after: currentIndex)
        guard let nextIndex else { return nil }
        return itemList?[safe: nextIndex]
    }
    
    private var previousItem: FeedItemModel? {
        guard let feedItem else { return nil }
        guard let currentIndex = itemList?.firstIndex(of: feedItem) else { return nil }
        let previousIndex = itemList?.index(before: currentIndex)
        guard let previousIndex else { return nil }
        return itemList?[safe: previousIndex]
    }
    
    private var nextItemAvailable: Bool {
        return nextItem != nil
    }
    
    private var previousItemAvailable: Bool {
        return previousItem != nil
    }
    
    init(feedItem: Binding<FeedItemModel?>, feed: FeedModel?) {
        self._url = State(initialValue: feedItem.wrappedValue?.url ?? URL(string: "https://localhost")!)
        self._feedItem = feedItem
        self.itemList = (feed?.items?.allObjects as? [FeedItemModel])?.sorted(by: { a, b in
            a.publicationDate! > b.publicationDate!
        })
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
                                .toolbar {
                                    ToolbarItemGroup {
                                        if loadingProgress != 1.0 {
                                            ProgressView()
                                        }
                                    }
                                    ToolbarItemGroup(placement: .bottomBar) {
                                        Spacer()
                                        
                                        Button {
                                            if let previousItem {
                                                feedItem = previousItem
                                            }
                                        } label: {
                                            Label("Previous article", systemSymbol: .chevronUp)
                                        }
                                        .disabled(!previousItemAvailable)
                                        
                                        Button {
                                            if let nextItem {
                                                feedItem = nextItem
                                            }
                                        } label: {
                                            Label("Next article", systemSymbol: .chevronDown)
                                        }
                                        .disabled(!nextItemAvailable)
                                    }
                                }
                        }
                    }
#endif
                }
                .onChange(of: loadingProgress) { newValue in
                    if newValue == 1.0 {
                        self.feedItem?.read = true
                        
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
            if let url = newValue?.url {
                self.url = url
            }
        }
    }
}

struct ReaderView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let feed = try! FeedKit.FeedParser(URL: URL(string: "https://9to5mac.com/feed")!).parse().get().rssFeed
        let item = FeedItemModel(from: feed!.items!.first!, context: context)
        
        return NavigationStack {
            ReaderView(feedItem: .constant(item), feed: nil)
        }
    }
}
