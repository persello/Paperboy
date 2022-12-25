//
//  FeedItemListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedItemListView: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var feed: FeedModel
    @FetchRequest<FeedItemModel> var items: FetchedResults<FeedItemModel>
    
    @State private var selection: FeedItemModel? = nil
    
    var unreadCount: Int {
        items.filter({!$0.read}).count
    }
    
    init(for feed: FeedModel) {
        self.feed = feed
        
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
                    NavigationLink {
                        ReaderView(feedItem: item)
                    } label: {
                        FeedItemListRow(feedItem: item)
                            .padding(4)
                    }
                    .swipeActions {
                        Button {
                            item.read.toggle()
                            
                            // TODO: Error management.
                            try? context.save()
                        } label: {
                            Label(item.read ? "Mark as unread" : "Mark as read", systemSymbol: item.read ? .trayFull : .eyeglasses)
                        }
                        .tint(item.read ? .blue : .orange)
                    }
                }
            }
            .listStyle(BorderedListStyle(alternatesRowBackgrounds: true))
        }
        .refreshable {
            Task {
                await feed.refresh()
            }
        }
        .toolbar {
            #if os(macOS)
            Button {
                Task.detached {
                    await feed.refresh()
                }
            } label: {
                Label("Refresh", systemSymbol: .arrowClockwise)
            }
            #endif
        }
        .task(id: feed) {
            await feed.refresh()
        }
        .navigationTitle(feed.title ?? "Unnamed feed")
        .navigationSubtitle(unreadCount > 0 ? "\(unreadCount) to read" : "You're up to date")
    }
}

struct FeedItemsListView_Previews: PreviewProvider {

    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let ninetofivemac = FeedModel(context: context)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.url = URL(string: "https://9to5mac.com/feed")
        
        return FeedItemListView(for: ninetofivemac)
                .environment(\.managedObjectContext, context)
    }
}
