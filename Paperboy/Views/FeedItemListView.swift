//
//  FeedItemListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedItemListView: View {
    @Environment(\.managedObjectContext) var context
    @Binding var selection: FeedItemModel?
    @ObservedObject var selectedFeed: FeedModel
    @FetchRequest<FeedItemModel> var items: FetchedResults<FeedItemModel>
    
    var unreadCount: Int {
        items.filter({!$0.read}).count
    }
    
    init(selectedItem: Binding<FeedItemModel?>, in feed: FeedModel) {
        self.selectedFeed = feed
        self._selection = selectedItem
        
        let request = FeedItemModel.fetchRequest()
        request.predicate = NSPredicate(format: "feed.url = %@", feed.url! as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FeedItemModel.publicationDate, ascending: false)
        ]
        
//        request.fetchLimit = 100
        
        self._items = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var body: some View {
        Group {
            List(selection: $selection) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        FeedItemListRow(feedItem: item)
                            .padding(4)
                    }
                    .swipeActions {
                        Button {
                            item.read.toggle()
                        } label: {
                            Label(item.read ? "Mark as unread" : "Mark as read", systemImage: item.read ? "tray.full" : "eyeglasses")
                        }
                        .tint(item.read ? .blue : .orange)
                    }
                }
            }
            .listStyle(BorderedListStyle(alternatesRowBackgrounds: true))
        }
        .refreshable {
            Task {
                await selectedFeed.refresh()
            }
        }
        .toolbar {
            #if os(macOS)
            Button {
                Task.detached {
                    await selectedFeed.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            #endif
        }
        .task(id: selectedFeed) {
            await selectedFeed.refresh()
        }
        .navigationTitle(selectedFeed.title ?? "Unnamed feed")
        .navigationSubtitle(unreadCount > 0 ? "\(unreadCount) to read" : "You're up to date")
    }
}

struct FeedItemsListView_Previews: PreviewProvider {

    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let ninetofivemac = FeedModel(context: context)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.url = URL(string: "https://9to5mac.com/feed")
        
        return FeedItemListView(selectedItem: .constant(nil), in: ninetofivemac)
                .environment(\.managedObjectContext, context)
    }
}
