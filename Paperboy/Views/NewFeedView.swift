//
//  NewFeedView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import FeedKit

struct NewFeedView: View {
    private var context = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
    @State var link: String = ""
    @State var title: String = ""
    @State var feed: FeedModel? = nil
    @State var parsing: Bool = false
    
    var body: some View {
        VStack {
            Group {
                
                // We can't make feed an @ObservableObject here, so we poll in order to see when it gets an icon.
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    if parsing {
                        ProgressView()
                    } else if let icon = feed?.iconImage {
                        // TODO: Move defaults to model.
                        Image(icon, scale: 1, label: Text(feed?.title ?? "Unnamed feed"))
                            .resizable()
                    } else {
                        Image(systemName: "newspaper.fill")
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
                if feed != nil {
                    TextField("Title", text: $title, prompt: Text(feed?.title ?? "Untitled feed"))
                }
            }
            .formStyle(.grouped)
            .onChange(of: link) { newValue in
                guard let url = URL(string: link) else {
                    if let feed {
                        context.delete(feed)
                        self.feed = nil
                    }
                    return
                }
                
                // TODO: Accept website links and scan for rss rel.
                
                // TODO: Put this abomination inside FeedModel convenience initialiser.
                let parser = FeedParser(URL: url)
                
                self.parsing = true
                parser.parseAsync(result: { result in
                    
                    defer {
                        self.parsing = false
                    }
                    
                    guard let newFeed = try? result.get() else {
                        DispatchQueue.main.async {
                            if let feed {
                                context.delete(feed)
                                try? context.save()
                                self.feed = nil
                            }
                        }
                        return
                    }
                    
                    guard let rssFeed = newFeed.rssFeed else {
                        DispatchQueue.main.async {
                            if let feed {
                                context.delete(feed)
                                try? context.save()
                                self.feed = nil
                            }
                        }
                        return
                    }
                    
                    let model = FeedModel(context: context)
                    model.url = url
                    model.title = rssFeed.title
                    try? model.refresh()
                    
                    if let feed {
                        context.delete(feed)
                    }
                    
                    self.feed = model
                    
                    DispatchQueue.main.async {
                        try? context.save()
                    }
                })
            }
            
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel, action: {
                    
                })
                .controlSize(.large)
                
                Button("Add", action: {
                    
                })
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(self.feed == nil)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .padding()
    }
}

struct NewFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewFeedView()
    }
}
