//
//  FeedItemsListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import PredicateKit

struct FeedItemsListView: View {
    @Environment(\.managedObjectContext) var context
    @Binding var selection: FeedItemModel?
    @ObservedObject var selectedFeed: FeedModel
    
    var body: some View {
        Group {
            if let items = (selectedFeed.items?.allObjects as? [FeedItemModel])?.prefix(100) {
                List(selection: $selection) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            Text(item.title ?? "Unnamed item")
                        }
                    }
                }
            } else {
                Text("Unable to fetch items.")
            }
        }
        .refreshable {
            try? selectedFeed.refresh()
        }
        .toolbar {
            #if os(macOS)
            Button {
                Task.detached {
                    try? await selectedFeed.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            #endif
        }
        .task(id: selectedFeed) {
            try? selectedFeed.refresh()
        }
        .navigationTitle(selectedFeed.title ?? "Unnamed feed")
    }
}

struct FeedItemsListView_Previews: PreviewProvider {

    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let feed = FeedModel(context: context)
        feed.title = "Antani's feed"
        
        let item = FeedItemModel(context: context)
        item.title = "Antani's dinner"

        feed.addToItems(item)
        
        return NavigationView {
            FeedItemsListView(selection: .constant(nil), selectedFeed: feed)
                .environment(\.managedObjectContext, context)
        }
    }
}
