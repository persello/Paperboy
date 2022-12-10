//
//  FeedListRow.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI

struct FeedListRow: View {
    @ObservedObject var feed: FeedModel
    var body: some View {
        Label {
            Text(feed.title ?? "Unnamed feed")
        } icon: {
            if feed.status == FeedModel.Status.refreshing.rawValue {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if let image = feed.iconImage {
                Image(image, scale: 1, label: Text("aaa"))
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(4)
            } else {
                Image(systemName: "newspaper")
            }
        }
    }
}

struct FeedListRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let feed = FeedModel(context: context)
        feed.title = "Antani's feed"
        
        return FeedListRow(feed: feed)
    }
}
