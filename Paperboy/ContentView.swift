//
//  ContentView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import FeedKit

struct ContentView: View {
    @Environment(\.managedObjectContext) var context
    @State private var selectedFeed: FeedModel? = nil
    @State private var selectedItem: FeedItemModel? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FeedListView(selection: $selectedFeed)
                    .navigationTitle("Paperboy")
        } content: {
            if let selectedFeed {
                FeedItemListView(selectedItem: $selectedItem, in: selectedFeed)
            }
        } detail: {
            ReaderView(feedItem: $selectedItem)
                .onChange(of: selectedItem) { newValue in
                    newValue?.read = true
                    
                    // TODO: Error management.
                    try? context.save()
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}
