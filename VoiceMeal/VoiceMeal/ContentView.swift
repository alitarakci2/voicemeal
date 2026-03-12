//
//  ContentView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Kayıt", systemImage: "mic")
                }

            HistoryView()
                .tabItem {
                    Label("Geçmiş", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
