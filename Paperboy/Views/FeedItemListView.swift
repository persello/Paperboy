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
            List(selection: $selection) {
                ForEach(feed.groupedItems, id: \.0) { group in
                    Section(getDateString(for: group.0)) {
                        ForEach(group.1) { item in
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
                    try await feed.refresh(onlyAfter: 30)
                } catch URLError.networkConnectionLost {
                    // Do not show error dialogs in case of connection errors, since this action is not user initiated. Instead, set the appropriate status.
                    self.feed.setStatus(.error)
                }
            } errorCallback: { _ in
                self.feed.setStatus(.error)
            }
        }
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
        
        return FeedItemListView(feed: ninetofivemac)
                .environment(\.managedObjectContext, context)
    }
}
