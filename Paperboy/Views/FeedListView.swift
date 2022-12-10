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
    
    var body: some View {
        List(selection: $selection) {
            ForEach(feeds) { feed in
                NavigationLink(value: feed) {
                    FeedListRow(feed: feed)
                }
            }
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
