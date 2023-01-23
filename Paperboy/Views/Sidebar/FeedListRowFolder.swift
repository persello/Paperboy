//
//  FeedListRowFolder.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import SwiftUI

struct FeedListRowFolder: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.errorHandler) private var errorHandler
    
    @ObservedObject var folder: FeedFolderModel
    
    @State private var deleting: Bool = false
    
    var body: some View {
        Label(folder.normalisedName, systemSymbol: folder.symbol)
            .contextMenu {
                Button(role: .destructive) {
                    deleting = true
                } label: {
                    Label("Delete...", systemSymbol: .trash)
                }
            }
            .alert(isPresented: $deleting, content: {
                Alert(
                    title: Text("Are you sure you want to delete \"\(folder.normalisedName)\"?"),
                    message: Text("All the contained feeds will also be removed."),
                    primaryButton: .destructive(
                        Text("Delete"),
                        action: {
                            deleting = false

                            context.perform {
                                context.delete(folder)
                                errorHandler.tryPerform {
                                    try context.save()
                                }
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
        let context = PersistenceController.preview.container.viewContext
        
        let folder = FeedFolderModel(context: context)
        folder.icon = "folder"
        folder.name = "Folder"
        
        return FeedListRowFolder(folder: folder)
            .environment(\.managedObjectContext, context)
    }
}
