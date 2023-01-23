//
//  NewFeedView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import FeedKit
import CoreData

struct NewFeedView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.errorHandler) private var errorHandler
    
    @Binding var modalShown: Bool
    
    // Not great, but easier...
    @FocusState private var textFieldFocused: Bool
    @State private var localSearchContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
    @State private var title: String = ""
    @State private var selectedFeed: FeedModel? = nil
    @State var link: String
    @State private var parsing: Bool = false
    @State private var searching: Bool = false
    @State private var foundFeeds: [FeedDiscovery.DiscoveredFeed] = []
    
    func updateFeedList() async {
        self.searching = true
        if let url = URL(string: link) {
            for await feed in FeedDiscovery.start(for: url, in: localSearchContext) {
                foundFeeds.append(feed)
            }
        } else {
            foundFeeds = []
            self.selectedFeed = nil
        }
        
        self.searching = false
    }
    
    var body: some View {
        CustomSheet {
            VStack {
                Group {
                    
                    // We can't make feed an @ObservableObject here, so we poll in order to see when it gets an icon.
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        if parsing {
                            ProgressView()
                        } else if let feed = selectedFeed,
                                  let icon = feed.iconImage {
                            Image(icon, scale: 1, label: Text(feed.normalisedTitle))
                                .resizable()
                        } else {
                            Image(systemSymbol: .newspaperFill)
                                .font(.largeTitle)
                        }
                    }
                }
                .frame(width: 100, height: 100)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                
                Text("New feed")
                    .font(.largeTitle.bold())
                
                Group {
                    Form {
                        Section {
                            TextField("Link", text: $link, prompt: Text("Feed or website link"))
                                .focused($textFieldFocused)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
#endif
                            
                            if let selectedFeed {
                                TextField("Title", text: $title, prompt: Text(selectedFeed.normalisedTitle))
                            }
                        }
                        
                        if !foundFeeds.isEmpty && selectedFeed == nil {
                            Section("Found feeds") {
                                ForEach(foundFeeds) { result in
                                    Button {
                                        selectedFeed = result.feed
                                    } label: {
                                        FeedLabel(feed: result.feed, showsBadge: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                
                if link.isEmpty {
                    Text("Feeds can also be added directly from Safari by clicking on a feed link.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                        
                }
            }
        } cancelButton: {
            Button {
                modalShown = false
            } label: {
                Text("Cancel")
            }

        } doneButton: {
            if searching && selectedFeed == nil {
                ProgressView()
            } else {
                Button {
                    // Push the feed to the "real" context.
                    
                    // TODO: Check for duplicates.
                                        
                    context.perform {
                        
                        Task {
                            
                            let new = try await FeedModel(url: selectedFeed!.url!, in: context)
                            await errorHandler.tryPerformAsync {
                                try await new.refresh()
                            }
                            
                            await context.perform {
                                context.insert(new)
                                errorHandler.tryPerform {
                                    try context.save()
                                }
                            }
                            
                            DispatchQueue.main.async {
                                modalShown = false
                            }
                        }
                    }
                } label: {
                    Text("Add")
                }
                .disabled(self.selectedFeed == nil)
            }
        }
        .onChange(of: title, perform: { newValue in
            self.selectedFeed?.title = newValue
        })
        .onChange(of: link) { newValue in
            Task {
                await self.updateFeedList()
            }
        }
        .onAppear {
            self.textFieldFocused = true
            Task {
                await self.updateFeedList()
            }
        }
    }
}

struct NewFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewFeedView(modalShown: .constant(true), link: "")
    }
}
