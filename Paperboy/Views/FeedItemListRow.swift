//
//  FeedItemListRow.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import SwiftSoup
import SFSafeSymbols
import Telescope

struct FeedItemListRow: View {
    @ScaledMetric var imageSize: CGFloat = 100
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @ObservedObject var feedItem: FeedItemModel
    
    // Expensive computations done in a task.
    @State var description: String? = nil
    @State var date: String? = nil
    
    // Computation finished marker.
    @State var taskCompleted: Bool = false
    
    static let imageCache = URLCache(memoryCapacity: 128 * 1024 * 1024, diskCapacity: 1 * 1024 * 1024 * 1024)
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var largeLayout: Bool {
        return dynamicTypeSize >= .accessibility1
    }
    
    var computedPadding: EdgeInsets {
        if feedItem.wallpaperURL != nil && !largeLayout {
            // Image shown...
            return .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        } else {
            return .init(top: 8, leading: 16, bottom: 8, trailing: 0)
        }
    }
        
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if !largeLayout,
               let wallpaperURL = feedItem.wallpaperURL {
                TImage(RemoteImage(imageURL: wallpaperURL))
                    .resizable()
                    .placeholder({
                        ProgressView()
                    })
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
#if os(macOS)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
#else
                    .clipShape(Rectangle())
#endif
            }
            
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    Group {
                        Text(feedItem.read ? "" : "\(Image(systemSymbol: .circleFill)) ")
                            .foregroundColor(.accentColor) +
                        
                        Text(feedItem.normalisedTitle)
                            .font(.headline)
                    }
                    .lineLimit(3)
                        
                    if let date {
                        Text(date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("21 December 2022, 18:15 PM")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .redacted(reason: .placeholder)
                    }
                }
                .imageScale(.small)
                
                if !largeLayout {
                    if let description {
                        Text(description)
                    } else if !taskCompleted {
                        Text(String(repeating: "A ", count: Int.random(in: 15...30)))
                            .redacted(reason: .placeholder)
                    }
                }
            }
            .padding(computedPadding)
        }
        .frame(maxHeight: imageSize)
#if os(macOS)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
#endif
        .task {
            feedItem.updateWallpaper()
            description = await feedItem.normalisedContentDescription
            if let publicationDate = feedItem.publicationDate {
                date = Self.dateFormatter.string(from: publicationDate)
            }
            taskCompleted = true
        }
        .contextMenu {
            // TODO: Context menu.
            Text("AAA")
        } preview: {
            ReaderView(feedItem: .constant(feedItem), feed: nil)
        }
    }
}

struct FeedItemListRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let item = FeedItemModel(context: context)
        item.title = "Antani had dinner today. This is a very, very long title that should wrap over multiple lines."
        item.publicationDate = .now
        item.articleDescription = """
        <div class="feat-image"><img src="https://9to5mac.com/wp-content/uploads/sites/6/2022/12/DSC04916-9to5-mac.jpg.jpeg?quality=82&#038;strip=all&#038;w=1280" /></div>
        <p>As work from home continues to be an option for many employees everywhere, it’s never a bad time to upgrade your setup with new accessories and gadgets. Head below as we roundup some of the best additions to your WFH setup, whether you’re buying for someone else this holiday season or crafting your own wish list. </p>
        <p> <a href="https://9to5mac.com/2022/12/10/9to5mac-gift-guide-upgrade-your-work-from-home-setup-with-these-products/#more-852697" class="more-link">more…</a></p>
        <p>The post <a rel="nofollow" href="https://9to5mac.com/2022/12/10/9to5mac-gift-guide-upgrade-your-work-from-home-setup-with-these-products/">9to5Mac Gift Guide: Upgrade your work-from-home setup with these products</a> appeared first on <a rel="nofollow" href="https://9to5mac.com">9to5Mac</a>.</p>
"""
        
        return FeedItemListRow(feedItem: item)
            .previewLayout(.sizeThatFits)
    }
}
