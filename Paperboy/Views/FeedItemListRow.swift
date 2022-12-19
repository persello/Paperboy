//
//  FeedItemListRow.swift
//  Paperboy
//
//  Created by Riccardo Persello on 10/12/22.
//

import SwiftUI
import SwiftSoup

struct FeedItemListRow: View {
    @ObservedObject var feedItem: FeedItemModel
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }
    
    // TODO: Move to FeedItemModel.
    var articleDescription: String? {
        guard let description = feedItem.articleDescription else {
            return nil
        }
        
        let document = try? SwiftSoup.parse(description)
        let paragraph = try? document?.select("p").first()
        let articleDescription = paragraph?.ownText()
        
        return articleDescription
    }
    
    var imageURL: URL? {
        guard let description = feedItem.articleDescription else {
            return nil
        }
        
        let document = try? SwiftSoup.parse(description)
        let image = try? document?.select("img").first()
        guard let src = try? image?.attr("src") else {
            return nil
        }
        
        return URL(string: src)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(feedItem.read ? "" : "\(Image(systemName: "circle.fill")) ")
                        .foregroundColor(.accentColor) +
                    
                    Text("\(feedItem.title ?? "Untitled article")")
                        .font(.headline)
                    
                    if let date = feedItem.publicationDate {
                        Text("\(self.dateFormatter.string(for: date)!)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .imageScale(.small)
                
                if let description = articleDescription {
                    Text(description)
                }
            }
        }
        .frame(maxHeight: 100)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
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
    }
}
