//
//  ContentView.swift
//  Reforged
//
//  Created by Boaz Briddick on 1/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    let lovableURL = URL(string: "https://reforged.lovable.app/")!

    var body: some View {
        ZStack {
            // The Web App
            WebView(url: lovableURL, isLoading: $isLoading)
                .edgesIgnoringSafeArea(.all) // Makes the web app full screen

            // Optional: Loading Spinner
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
            }
        }
    }
}
