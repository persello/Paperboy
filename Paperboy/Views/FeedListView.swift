//
//  FeedListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedListView: View {
    @Environment(\.managedObjectContext) var context
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.title, order: .reverse)],
        animation: .default
    ) private var feeds: FetchedResults<FeedModel>
    @Binding var selection: FeedModel?
    @State private var newFeedSheetPresented: Bool = false
    
    var body: some View {
        List(selection: $selection) {
            ForEach(feeds) { feed in
                NavigationLink(value: feed) {
                    FeedListRow(feed: feed)
                }
            }.onMove { iset, i in
                // TODO: Handle feed reordering.
            }
        }
        .toolbar {
            Button {
                newFeedSheetPresented = true
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
        .sheet(isPresented: $newFeedSheetPresented) {
            NewFeedView()
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext

        FeedListView(selection: .constant(nil))
            .environment(\.managedObjectContext, context)
    }
}
