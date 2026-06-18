//
//  app8800proApp.swift
//  app8800pro
//
//  Created by Aoody Concorde on 16/6/2026.
//

import SwiftUI

@main
struct app8800proApp: App {
    @StateObject private var store = RadioStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
