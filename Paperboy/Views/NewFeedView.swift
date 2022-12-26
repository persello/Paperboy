//
//  NewFeedView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import FeedKit

struct NewFeedView: View {
    @Environment(\.managedObjectContext) private var context
    
    @Binding var modalShown: Bool
    @Binding var link: String
    
    // Not great, but easier...
    @State private var localSearchContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
    @State private var title: String = ""
    @State private var selectedFeed: FeedModel? = nil
    @State private var parsing: Bool = false
    @State private var foundFeeds: [FeedDiscovery.DiscoveredFeed] = []
    
    func updateFeedList() async {
        if let url = URL(string: link) {
            foundFeeds = await FeedDiscovery.start(for: url, in: localSearchContext)
        } else {
            foundFeeds = []
            self.selectedFeed = nil
        }
    }
    
    var body: some View {
        VStack {
            Group {
                
                // We can't make feed an @ObservableObject here, so we poll in order to see when it gets an icon.
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    if parsing {
                        ProgressView()
                    } else if let feed = selectedFeed,
                              let icon = feed.iconImage {
                        // TODO: Move defaults to model.
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
            
            
            Text("Add a new feed")
                .font(.largeTitle.bold())
            
            Form {
                TextField("Link", text: $link, prompt: Text("https://example.com/feed.rss"))
                if let selectedFeed {
                    TextField("Title", text: $title, prompt: Text(selectedFeed.normalisedTitle))
                }
                
                if !foundFeeds.isEmpty && selectedFeed == nil {
                    Section("Found feeds") {
                        ForEach(foundFeeds) { result in
                            Button {
                                selectedFeed = result.feed
                            } label: {
                                FeedListRow(feed: result.feed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: title, perform: { newValue in
                self.selectedFeed?.title = newValue
            })
            .onChange(of: link) { newValue in
                self.selectedFeed = nil
                Task {
                    await self.updateFeedList()
                }
            }
            .onAppear {
                Task {
                    await self.updateFeedList()
                }
            }
            
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel, action: {
                    modalShown = false
                })
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Button("Add", action: {
                    // Push the feed to the "real" context.
                    guard let selectedFeed else {
                        // TODO: Error.
                        return
                    }
                    
                    // TODO: Check for duplicates.
                    
                    let _ = FeedModel(selectedFeed, in: context)
                    modalShown = false
                    
                    // TODO: Error management.
                    try? context.save()
                })
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(self.selectedFeed == nil)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .padding()
    }
}

struct NewFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewFeedView(modalShown: .constant(true), link: .constant("https://9to5mac.com"))
    }
}
