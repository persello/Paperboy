//
//  FeedLabel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI

struct FeedLabel: View {
    var feed: FeedModel
    var showsBadge: Bool = true
    
    var body: some View {
        Label {
            Text(feed.title)
        } icon: {
            if feed.status == FeedModel.Status.error {
                Image(systemSymbol: .boltHorizontalCircle)
                    .foregroundColor(.secondary)
            } else if feed.status == FeedModel.Status.refreshing {
                ProgressView()
                #if os(macOS)
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                #endif
            } else if let image = feed.iconImage {
                Image(image, scale: 1, label: Text(feed.title))
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(4)
            } else {
                Image(systemSymbol: .newspaper)
            }
        }
        .badge(showsBadge ? feed.unreadCount : 0)
    }
}

struct FeedListRow_Previews: PreviewProvider {
    static var previews: some View {
        
        let feed = FeedModel(title: "9to5Mac", url: URL(string: "https://9to5mac.com/feed")!)
        
        return FeedLabel(feed: feed)
    }
}
