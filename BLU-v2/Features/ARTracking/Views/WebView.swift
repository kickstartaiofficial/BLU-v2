//
//  WebView.swift
//  BLU-v2
//
//  WebView component for displaying web pages
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        // Configure for better performance
        // Note: javaScriptEnabled is deprecated, but we allow JS by default (WKWebView default)
        webView.allowsBackForwardNavigationGestures = false
        
        // Load URL immediately but only once
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // CRITICAL: Don't reload on every update - only load once in makeUIView
        // This prevents hangs and reload loops
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Navigation started
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Navigation finished
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Web View Screen

struct WebViewScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                WebView(url: url)
                    .ignoresSafeArea()
                    .opacity(isLoading ? 0 : 1)
                
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("BLU Baseball")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                // Fade in after a brief delay to allow web view to render
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isLoading = false
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Prevent split view on iPad
    }
}
