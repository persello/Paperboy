//
//  NewFeedView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import FeedKit

struct NewFeedView: View {
    @State var link: String = ""
    @State var title: String = ""
    @State var feed: FeedProtocol? = nil
    @State var parsing: Bool = false
    
    var body: some View {
        VStack {
            Group {
                if parsing {
                    ProgressView()
                } else if let iconURL = feed?.iconURL {
                    AsyncImage(url: iconURL) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }

                } else {
                    Image(systemName: "newspaper.fill")
                        .font(.largeTitle)
                }
            }
            .frame(width: 100, height: 100)
            .background(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            
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
                    feed = nil
                    return
                }
                
                let parser = FeedParser(URL: url)
                
                self.parsing = true
                parser.parseAsync(result: { result in
                    
                    defer {
                        self.parsing = false
                    }
                    
                    guard let feed = try? result.get() else {
                        DispatchQueue.main.async {
                            self.feed = nil
                        }
                        return
                    }
                    
                    guard let rssFeed = feed.rssFeed else {
                        DispatchQueue.main.async {
                            self.feed = nil
                        }
                        return
                    }
                    
                    self.feed = rssFeed
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
        .padding()
    }
}

struct NewFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewFeedView()
    }
}
