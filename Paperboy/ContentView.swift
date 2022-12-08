//
//  ContentView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import FeedKit

struct ContentView: View {
    @State private var selectedFeed: FeedModel? = nil
    @State private var selectedItem: (any FeedItemProtocol)? = nil
    
    var body: some View {
        NavigationSplitView {
                FeedListView(selection: $selectedFeed, feeds: [])
                    .navigationTitle("Paperboy")
        } content: {
            FeedItemsListView()
        } detail: {
            FeedItemContentView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
