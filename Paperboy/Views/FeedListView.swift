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
    @Environment(\.errorHandler) private var errorHandler
    
    @FetchRequest(sortDescriptors: [])
    private var feeds: FetchedResults<FeedModel>
    
    @FetchRequest(sortDescriptors: [])
    private var folders: FetchedResults<FeedFolderModel>
    
    @Binding var selection: FeedModel?
    
    @State private var newFeedSheetPresented: Bool = false
    @State private var newFolderSheetPresented: Bool = false
    
    @State private var newFeedLink: String = ""
    
    @State private var feedToBeDeleted: FeedModel? = nil
    @State private var folderToBeDeleted: FeedFolderModel? = nil
    
    private func refreshAllFeeds(immediate: Bool = false) async {
        await errorHandler.tryPerformAsync {
            for feed in feeds {
                Task {
                    do {
                        try await feed.refresh(onlyAfter: immediate ? 0 : 60)
                    } catch URLError.networkConnectionLost {
                        // Do not show error dialogs in case of connection errors, since this action is not user initiated. Instead, set the appropriate status.
                        feed.setStatus(.error)
                    }
                }
            }
        }
    }
    
    var uncategorisedFeeds: [FeedModel]? {
        let uncategorised = feeds.filter({
            $0.folder == nil
        })
        
        if uncategorised.count == 0 {
            return nil
        } else {
            return uncategorised
        }
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 3)) { _ in
            if feeds.count > 0 || folders.count > 0 {
                List(selection: $selection) {
                    ForEach(folders) { folder in
                        Section {
                            ForEach(folder.feeds?.allObjects as! [FeedModel]) { feed in
                                NavigationLink(value: feed) {
                                    FeedListRowFeed(feed: feed, folders: Array(folders))
                                }
                            }
                        } header: {
                            FeedListRowFolder(folder: folder)
                        }
                    }
                    
                    if let uncategorisedFeeds {
                        Section("Uncategorised") {
                            ForEach(uncategorisedFeeds) { feed in
                                NavigationLink(value: feed) {
                                    FeedListRowFeed(feed: feed, folders: Array(folders))
                                }
                            }
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
                .padding()
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
        .refreshable {
            await refreshAllFeeds(immediate: true)
        }
        .task() {
            await refreshAllFeeds()
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        return NavigationStack {
            FeedListView(selection: .constant(nil))
                .environment(\.managedObjectContext, context)
        }
    }
}
