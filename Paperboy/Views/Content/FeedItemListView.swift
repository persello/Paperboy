//
//  FeedItemListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedItemListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.errorHandler) private var errorHandler
    
    var feed: FeedModel
    @Binding var selection: FeedItemModel?
    
    @State private var groupedItems: [FeedModel.GroupedFeedItems]? = nil
    @State private var taskCompleted: Bool = false
    
    // @State private var searchText: String = ""
    
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
                                NavigationLink(value: item) {
                                    FeedItemListRow(feedItem: item)
#if os(macOS)
                                        .padding(4)
#endif
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                                .swipeActions {
                                    Button {
                                        item.read.toggle()
                                        errorHandler.tryPerform {
                                            try context.save()
                                        }
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
                //                .searchable(text: $searchText)
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
                .padding()
            }
        }
        .refreshable {
            Task {
                await errorHandler.tryPerformAsync {
                    try await feed.refresh()
                } errorCallback: { _ in
                    feed.status = .error
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
                        await feed.status = .error
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
                .disabled(feed.unreadCount == 0)
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
                    self.feed.status = .error
                }
                
                groupedItems = feed.groupedItems
                taskCompleted = true
            } errorCallback: { _ in
                self.feed.status = .error
                taskCompleted = true
            }
        }
        .onChange(of: feed, perform: { newValue in
            taskCompleted = false
        })
        .navigationTitle(feed.title)
#if os(macOS)
        .navigationSubtitle(feed.unreadCount > 0 ? "\(feed.unreadCount) to read" : "You're up to date")
#endif
    }
}

struct FeedItemsListView_Previews: PreviewProvider {
    
    static var previews: some View {
        let ninetofivemac = FeedModel(title: "9to5Mac", url: URL(string: "https://9to5mac.com/feed")!)
        
        return NavigationStack {
            FeedItemListView(feed: ninetofivemac, selection: .constant(nil))
        }
    }
}
