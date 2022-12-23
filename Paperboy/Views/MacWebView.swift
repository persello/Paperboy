//
//  MacWebView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 21/12/22.
//

import SwiftUI
import WebKit

struct MacWebView: NSViewRepresentable {
    
    typealias NSViewType = WKWebView

    @Binding var url: URL
    @Binding var loadingProgress: Double
        
    private var webView: WKWebView = WKWebView()
    
    private var request: URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
        request.assumesHTTP3Capable = true
        return request
    }
    
    init(url: Binding<URL>, loadingProgress: Binding<Double>) {
        self._url = url
        self._loadingProgress = loadingProgress
    }
    
    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        private var parent: MacWebView
        private var observer: NSKeyValueObservation?
        
        init(_ parent: MacWebView) {
            self.parent = parent
            super.init()
            
            observer = self.parent.webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.loadingProgress = webView.estimatedProgress
                }
            }
        }
        
        deinit {
            observer = nil
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let newURL = navigationAction.request.url {
                self.parent.url = newURL
            }
            
            return .allow
        }
    }
}


struct MacWebView_Previews: PreviewProvider {
    static var previews: some View {
        MacWebView(url: .constant(URL(string: "https://apple.com")!), loadingProgress: .constant(1))
    }
}
