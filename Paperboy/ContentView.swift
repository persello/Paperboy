//
//  ContentView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import FeedKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FeedListView()
                .navigationTitle("Paperboy")
        } content: {
            EmptyView()
        } detail: {
            EmptyView()
        }
        .withErrorHandling()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}
