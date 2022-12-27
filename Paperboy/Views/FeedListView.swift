//
//  FeedListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import SFSafeSymbols

struct FeedListView: View {
    @Environment(\.managedObjectContext) private var context
    
    @FetchRequest(sortDescriptors: []) private var feeds: FetchedResults<FeedModel>
    @FetchRequest(sortDescriptors: []) private var folders: FetchedResults<FeedFolderModel>
    
    @State private var selection: FeedListViewModel? = nil
    @State private var newFeedSheetPresented: Bool = false
    @State private var newFolderSheetPresented: Bool = false
    @State private var newFeedLink: String = ""
    @State private var feedToBeDeleted: FeedModel? = nil
    @State private var folderToBeDeleted: FeedFolderModel? = nil
    
    private var structure: [FeedListViewModel] {
        var root = folders.sorted(by: { a, b in
            a.normalisedName < b.normalisedName
        }).map({ folder in
            FeedListViewModel(folder: folder)
        })
        
        let rootFeeds = feeds.sorted(by: { a, b in
            a.normalisedTitle < b.normalisedTitle
        }).filter { feed in
            feed.folder == nil
        }
        
        root.append(contentsOf: rootFeeds.map({ feed in
            FeedListViewModel(feed: feed)
        }))
        
        return root
    }
    
    var body: some View {
        List(selection: $selection) {
            OutlineGroup(structure, children: \.children) { item in
                switch item.content {
                case .feed(let feed):
                    NavigationLink {
                        FeedItemListView(feed: feed)
                    } label: {
                        FeedListRow(feed: feed)
                    }
                    .contextMenu {
                        // Sucks but I can't seem to face up to the fact that I can't use Core Data.
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Button {
                                feed.markAllAsRead()
                            } label : {
                                Text("Mark all as read")
                            }
                            .disabled(feed.itemsToRead == 0)
                            
                            Divider()
                        }
                        
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
                        
                        Button {
                            feedToBeDeleted = feed
                        } label: {
                            Text("Delete...")
                        }
                    }
                    .alert(item: $feedToBeDeleted, content: { feed in
                        Alert(
                            title: Text("Are you sure you want to delete \"\(feed.normalisedTitle)\"?"),
                            message: Text("Once you delete this feed, you'll need to add it again if you want it back."),
                            primaryButton: .default(
                                Text("Delete"),
                                action: {
                                    feedToBeDeleted = nil
                                    context.delete(feed)

                                    try? context.save()
                                }
                            ),
                            secondaryButton: .cancel()
                        )
                    })
                case .folder(let folder):
                    Label(folder.normalisedName, systemSymbol: folder.symbol)
                        .contextMenu {
                            Button {
                                folderToBeDeleted = folder
                            } label: {
                                Text("Delete...")
                            }
                        }
                        .alert(item: $folderToBeDeleted, content: { folder in
                            Alert(
                                title: Text("Are you sure you want to delete \"\(folder.normalisedName)\"?"),
                                message: Text("All the contained feeds will also be removed."),
                                primaryButton: .default(
                                    Text("Delete"),
                                    action: {
                                        folderToBeDeleted = nil
                                        context.delete(folder)
                                        
                                        try? context.save()
                                    }
                                ),
                                secondaryButton: .cancel()
                            )
                        })
                }
            }
        }
        .toolbar {
            Menu {
                Button {
                    newFolderSheetPresented = true
                } label: {
                    Label("New folder...", systemSymbol: .folderBadgePlus)
                }
            } label: {
                Image(systemSymbol: .plus)
            } primaryAction: {
                newFeedSheetPresented = true
            }
            .menuStyle(.button)
            .frame(width: 60)
        }
        .sheet(isPresented: $newFeedSheetPresented) {
            NewFeedView(modalShown: $newFeedSheetPresented, link: $newFeedLink)
        }
        .sheet(isPresented: $newFolderSheetPresented) {
            NewFolderView(modalShown: $newFolderSheetPresented)
        }
        .onOpenURL { url in
            newFeedLink = url.absoluteString
            newFeedSheetPresented = true
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        FeedListView()
            .environment(\.managedObjectContext, context)
    }
}
