//
//  FeedListView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI

struct FeedListView: View {    
    @Binding var selection: FeedModel?
    var feeds: [FeedModel]
    
    var body: some View {
        List(selection: $selection) {
            ForEach(feeds) { feed in
                NavigationLink(value: feed) {
                    Text(feed.title)
                }
            }
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        FeedListView(selection: .constant(nil), feeds: [])
    }
}
