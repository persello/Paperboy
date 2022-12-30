//
//  FeedItemListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedItemListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var errorHandler: ErrorHandler
    
    @ObservedObject var feed: FeedModel
    
    @State private var selection: FeedItemModel? = nil
    @State private var groupedItems: [FeedModel.GroupedFeedItems]? = nil
    @State private var taskCompleted: Bool = false
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
    
    func getDateString(for date: Date?) -> String {
        guard let date else {
            return "Unknown date"
        }
        
        return dateFormatter.string(for: date) ?? "Unknown date"
    }
    
    var body: some View {
        Group {
            if let groupedItems,
               groupedItems.count > 0,
               taskCompleted {
                List(selection: $selection) {
                    ForEach(groupedItems) { (group: FeedModel.GroupedFeedItems) in
                        Section(group.title ?? "Unknown date") {
                            ForEach(group.items) { (item: FeedItemModel) in
                                NavigationLink {
                                    ReaderView(feedItem: item)
                                } label: {
                                    FeedItemListRow(feedItem: item)
#if os(macOS)
                                        .padding(4)
#endif
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                                .contextMenu {
                                    // TODO: Context menu.
                                    Text("AAA")
                                } preview: {
                                    ReaderView(feedItem: item)
                                }
                                .swipeActions {
                                    Button {
                                        item.read.toggle()

                                        // TODO: Error management.
                                        try? context.save()
                                    } label: {
                                        Label(item.read ? "Mark as unread" : "Mark as read", systemSymbol: item.read ? .trayFull : .eyeglasses)
#if os(iOS)
                                            .labelStyle(.iconOnly)
#endif
                                    }
                                    .tint(item.read ? .blue : .orange)
                                }
                            }
                        }
                    }
                }
#if os(macOS)
                .listStyle(.bordered(alternatesRowBackgrounds: true))
#elseif os(iOS)
                .listStyle(.plain)
#endif
            } else if !taskCompleted {
                ProgressView()
            } else {
                VStack {
                    Text("No articles")
                        .font(.title)
                    Text("This feed does not contain any article.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .refreshable {
            Task {
                await errorHandler.tryPerformAsync {
                    try await feed.refresh()
                } errorCallback: { _ in
                    feed.setStatus(.error)
                }
            }
        }
        .toolbar {
#if os(macOS)
            Button {
                Task.detached {
                    await errorHandler.tryPerformAsync {
                        try await feed.refresh()
                    } errorCallback: { _ in
                        await feed.setStatus(.error)
                    }
                }
            } label: {
                Label("Refresh", systemSymbol: .arrowClockwise)
            }
#endif

            Menu {
                Button {
                    feed.markAllAsRead()
                } label: {
                    Label("Mark all as read", systemSymbol: .eye)
                }
                .disabled(feed.itemsToRead == 0)
            } label: {
                Label("View options...", systemSymbol: .ellipsisCircle)
            }
        }
        .task(id: feed) {
            await errorHandler.tryPerformAsync {
                do {
                    try await feed.refresh(onlyAfter: 60)
                } catch URLError.networkConnectionLost {
                    // Do not show error dialogs in case of connection errors, since this action is not user initiated. Instead, set the appropriate status.
                    self.feed.setStatus(.error)
                }
                
                groupedItems = feed.groupedItems
                taskCompleted = true
            } errorCallback: { _ in
                self.feed.setStatus(.error)
                taskCompleted = true
            }
        }
        .onChange(of: feed, perform: { newValue in
            taskCompleted = false
        })
        .navigationTitle(feed.normalisedTitle)
        #if os(macOS)
        .navigationSubtitle(feed.itemsToRead > 0 ? "\(feed.itemsToRead) to read" : "You're up to date")
        #endif
    }
}

struct FeedItemsListView_Previews: PreviewProvider {
    
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let ninetofivemac = FeedModel(context: context)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.url = URL(string: "https://9to5mac.com/feed")
        
        return NavigationStack {
            FeedItemListView(feed: ninetofivemac)
                .environmentObject(ErrorHandler())
                .environment(\.managedObjectContext, context)
        }
    }
}
