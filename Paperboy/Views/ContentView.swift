//
//  ContentView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import FeedKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedFeed: FeedModel?
    @State private var selectedFeedItem: FeedItemModel?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FeedListView(selection: $selectedFeed)
                .navigationTitle("Paperboy")
                .navigationSplitViewColumnWidth(min: 150, ideal: 300)
        } content: {
            Group {
                if let selectedFeed {
                    FeedItemListView(feed: selectedFeed, selection: $selectedFeedItem)
                } else {
                    VStack {
                        Text("No feed selected")
                            .font(.title)
                        Text("Choose a feed from the sidebar.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 300)
        } detail: {
            Group {
                if selectedFeedItem != nil {
                    // Not great...
                    ReaderView(feedItem: $selectedFeedItem, feed: selectedFeed)
                } else {
                    Image(systemSymbol: .newspaper)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .foregroundStyle(.quaternary)
                        .padding()
                        .toolbar {
                            // A small hack for preventing the items of the second column to be displayed over the third when the app is first initialised.
                            Text("")
                        }
                }
            }
        }
        .withErrorHandling()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
