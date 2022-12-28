//
//  iOSWebView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import SwiftUI
import WebKit

#if os(iOS)
struct iOSWebView: UIViewRepresentable {
    
    typealias UIViewType = WKWebView

    @Binding var url: URL
    @Binding var loadingProgress: Double
    @Binding var error: Error?
        
    private var webView: WKWebView!
    
    private var request: URLRequest {
        var request = URLRequest(url: url)
        request.assumesHTTP3Capable = true
        return request
    }
    
    init(url: Binding<URL>, loadingProgress: Binding<Double>, error: Binding<Error?> = .constant(nil)) {
        self.webView = WKWebView()
        self._url = url
        self._loadingProgress = loadingProgress
        self._error = error
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView.configuration.allowsInlineMediaPlayback = false

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ContentBlockingRules",
            encodedContentRuleList: try! String(
                contentsOf: Bundle.main.url(
                    forResource: "ContentBlacklist",
                    withExtension: "json"
                )!
            )
        ) { contentRuleList, error in
            if error != nil {
                // TODO: Handle error
            } else if let contentRuleList = contentRuleList {
                webView.configuration.userContentController.add(contentRuleList)
            } else {
                // TODO: Handle error
            }
        }
        
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if uiView.url == self.url {
            return
        }
        
        uiView.load(request)
        DispatchQueue.main.async {
            self.error = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        private var parent: iOSWebView
        private var progressObserver: NSKeyValueObservation?
        
        init(_ parent: iOSWebView) {
            self.parent = parent
            super.init()
            
            progressObserver = self.parent.webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.loadingProgress = webView.estimatedProgress
                }
            }
        }
        
        deinit {
            progressObserver = nil
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let newURL = navigationAction.request.url {
                self.parent.url = newURL
            }
            
            return .allow
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            
            if nsError.code == NSURLErrorCancelled {
                return
            } else {
                DispatchQueue.main.async {
                    self.parent.error = error
                }
            }
        }
    }
}


struct iOSWebView_Previews: PreviewProvider {
    static var previews: some View {
        iOSWebView(url: .constant(URL(string: "https://apple.com")!), loadingProgress: .constant(1))
    }
}
#endif
