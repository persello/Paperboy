//
//  FeedListRowFolder.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import SwiftUI

struct FeedListRowFolder: View {
    @Environment(\.modelContext) private var context
    @Environment(\.errorHandler) private var errorHandler
    
    var folder: FeedFolderModel
    
    @State private var deleting: Bool = false
    
    var body: some View {
        Label(folder.name, systemSymbol: folder.symbol)
            .contextMenu {
                Button(role: .destructive) {
                    deleting = true
                } label: {
                    Label("Delete...", systemSymbol: .trash)
                }
            }
            .alert(isPresented: $deleting, content: {
                Alert(
                    title: Text("Are you sure you want to delete \"\(folder.name)\"?"),
                    message: Text("All the contained feeds will also be removed."),
                    primaryButton: .destructive(
                        Text("Delete"),
                        action: {
                            deleting = false

                            context.delete(folder)
                            errorHandler.tryPerform {
                                try context.save()
                            }
                        }
                    ),
                    secondaryButton: .cancel()
                )
            })
    }
}

struct FeedListRowFolder_Previews: PreviewProvider {
    static var previews: some View {
        let folder = FeedFolderModel(name: "Folder")
        
        return FeedListRowFolder(folder: folder)
    }
}
