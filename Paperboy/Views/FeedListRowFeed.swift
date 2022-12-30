//
//  FeedListRowFeed.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import SwiftUI

struct FeedListRowFeed: View {
    @Environment(\.managedObjectContext) private var context
    
    @ObservedObject var feed: FeedModel
    
    var folders: [FeedFolderModel]
    @State private var deleting: Bool = false
    
    var body: some View {
        FeedLabel(feed: feed)
        .contextMenu {
            Button {
                feed.markAllAsRead()
            } label : {
                Label("Mark all as read", systemSymbol: .eye)
            }
            .disabled(feed.unreadCount == 0)
            
            Divider()
            
            Menu("Move to folder") {
                ForEach(folders) { folder in
                    Button {
                        folder.addToFeeds(feed)
                        try? context.save()
                    } label: {
                        Label(folder.normalisedName, systemSymbol: folder.symbol)
                    }
                }
            }
            .labelStyle(.titleAndIcon)
            
            Button(role: .destructive) {
                deleting = true
            } label: {
                Label("Delete...", systemSymbol: .trash)
            }
        }
        .alert(isPresented: $deleting, content: {
            Alert(
                title: Text("Are you sure you want to delete \"\(feed.normalisedTitle)\"?"),
                message: Text("Once you delete this feed, you'll need to add it again if you want it back."),
                primaryButton: .destructive(
                    Text("Delete"),
                    action: {
                        deleting = false
                        context.delete(feed)
                        
                        try? context.save()
                    }
                ),
                secondaryButton: .cancel()
            )
        })
    }
}

struct FeedListRowFeed_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let feed = FeedModel(context: context)
        feed.title = "9to5Mac"
        feed.url = URL(string: "https://9to5mac.com/feed")!
        
        return FeedListRowFeed(feed: feed, folders: [])
            .environment(\.managedObjectContext, context)
    }
}
