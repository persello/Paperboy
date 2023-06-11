//
//  FeedListRowFeed.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import SwiftUI
import SwiftData

struct FeedListRowFeed: View {
    @Environment(\.modelContext) private var context
    @Environment(\.errorHandler) private var errorHandler
    
    var feed: FeedModel
    
    var folders: [FeedFolderModel]
    @State private var deleting: Bool = false
    
    var body: some View {
        FeedLabel(feed: feed)
        .contextMenu {
//            Button {
//                feed.markAllAsRead()
//            } label : {
//                Label("Mark all as read", systemSymbol: .eye)
//            }
//            .disabled(feed.unreadCount == 0)
            
//            Divider()
//            
//            Menu("Move to folder") {
//                ForEach(folders) { folder in
//                    Button {
//                        context.perform {
//                            folder.feeds.append(feed)
//                            
//                            errorHandler.tryPerform {
//                                try context.save()
//                            }
//                        }
//                    } label: {
//                        Label(folder.normalisedName, systemSymbol: folder.symbol)
//                    }
//                }
//            }
//            .labelStyle(.titleAndIcon)
//            
//            Button(role: .destructive) {
//                deleting = true
//            } label: {
//                Label("Delete...", systemSymbol: .trash)
//            }
        }
        .alert(isPresented: $deleting, content: {
            Alert(
                title: Text("Are you sure you want to delete \"\(feed.title)\"?"),
                message: Text("Once you delete this feed, you'll need to add it again if you want it back."),
                primaryButton: .destructive(
                    Text("Delete"),
                    action: {
                        deleting = false
                        
                        context.delete(feed)
                        errorHandler.tryPerform {
                            try context.save()
                        }
                    }
                ),
                secondaryButton: .cancel()
            )
        })
    }
}

struct FeedListRowFeed_Previews: PreviewProvider {
    static var previews: some View {
        let feed = FeedModel(title: "9to5Mac", url: .init(string: "https://9to5mac.com/feed")!)
        
        return FeedListRowFeed(feed: feed, folders: [])
    }
}
