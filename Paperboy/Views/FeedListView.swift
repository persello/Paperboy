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
    
    @FetchRequest(sortDescriptors: [])
    private var feeds: FetchedResults<FeedModel>
    
    @FetchRequest(sortDescriptors: [])
    private var folders: FetchedResults<FeedFolderModel>
    
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
        // TODO: Not an ideal solution. Find alternatives.
        TimelineView(.periodic(from: .now, by: 3)) { _ in
            if structure.count > 0 {
                List(selection: $selection) {
                    OutlineGroup(structure, children: \.children) { item in
                        switch item.content {
                        case .feed(let feed):
                            FeedListRowFeed(feed: feed, folders: Array(folders))
                        case .folder(let folder):
                            FeedListRowFolder(folder: folder)
                        }
                    }
                }
            } else {
                VStack {
                    Text("No feeds")
                        .font(.title)
                    Text("Tap on \(Image(systemSymbol: .plus)) to add a new feed.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .toolbar {
#if os(macOS)
            Menu {
                Button {
                    newFolderSheetPresented = true
                } label: {
                    Label("New folder...", systemSymbol: .folderBadgePlus)
                }
            } label: {
                Label("New feed...", systemSymbol: .plus)
            } primaryAction: {
                newFeedSheetPresented = true
            }
            .menuStyle(.button)
            .frame(width: 60)
#else
            Menu {
                Button {
                    newFeedSheetPresented = true
                } label: {
                    Label("New feed...", systemSymbol: .linkBadgePlus)
                }
                
                Button {
                    newFolderSheetPresented = true
                } label: {
                    Label("New folder...", systemSymbol: .folderBadgePlus)
                }
            } label: {
                Label("New...", systemSymbol: .plus)
            }
#endif
        }
        .sheet(isPresented: $newFeedSheetPresented) {
            NewFeedView(modalShown: $newFeedSheetPresented, link: newFeedLink)
        }
        .sheet(isPresented: $newFolderSheetPresented) {
            NewFolderView(modalShown: $newFolderSheetPresented)
        }
        .onOpenURL { url in
            newFeedLink = url.absoluteString
            newFeedSheetPresented = true
        }
        .onChange(of: newFeedSheetPresented) { newValue in
            // Reset the new feed link after the first disappearance of the sheet.
            if newFeedSheetPresented == false {
                newFeedLink = ""
            }
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        return NavigationStack {
            FeedListView()
                .environment(\.managedObjectContext, context)
        }
    }
}
