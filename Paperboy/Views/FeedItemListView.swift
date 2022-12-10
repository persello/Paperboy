//
//  FeedItemListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import PredicateKit

struct FeedItemListView: View {
    @Environment(\.managedObjectContext) var context
    @Binding var selection: FeedItemModel?
    @ObservedObject var selectedFeed: FeedModel
    
    var body: some View {
        Group {
            if let items = (selectedFeed.items?.allObjects as? [FeedItemModel])?
                .sorted(by: { a, b in
                    a.publicationDate > b.publicationDate
                }).prefix(100) {
                
                List(selection: $selection) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            FeedItemListRow(feedItem: item)
                                .padding(4)
                        }
                        .swipeActions {
                            Button {
                                
                            } label: {
                                Label("Antani", systemImage: "eyeglasses")
                            }
                            .tint(.orange)

                            Button {
                                
                            } label: {
                                Label("Antani", systemImage: "tray.full")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(BorderedListStyle(alternatesRowBackgrounds: true))
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
        .navigationSubtitle("3 unread")
    }
}

struct FeedItemsListView_Previews: PreviewProvider {

    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let ninetofivemac = FeedModel(context: context)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.url = URL(string: "https://9to5mac.com/feed")
        
        return FeedItemListView(selection: .constant(nil), selectedFeed: ninetofivemac)
                .environment(\.managedObjectContext, context)
    }
}
