//
//  ContentView.swift
//  Telestrations
//
//  Created by Aaron Butler on 1/30/24.
//

import SwiftUI
import FirebaseDatabase

struct ContentView: View {
    
    @EnvironmentObject var game: GameStore
    @State private var navPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                TextField("Name", text: $game.name)
                    .padding()
                HStack {
                    Button {
                        game.isShowingAlert = true
                    } label: {
                        Text("Join Game")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.name.isEmpty)
                    
                    Spacer()
                        .frame(width: 50)
                    
                    Button {
                        Task {
                            let success = await game.startGame()
                            
                            if success {
                                navPath.append(game.gameCode)
                            }
                        }
                    } label: {
                        Text("Start Game")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.name.isEmpty)
                }
            }
            .navigationDestination(for: String.self) { _ in
                WaitingRoomView()
                    .environmentObject(game)
            }
            .alert("Enter Game Code", isPresented: $game.isShowingAlert) {
                TextField("Game Code", text: $game.gameCode)
                Button("Join") {
                    Task {
                        let success = await game.joinGame()
                        
                        if success {
                            navPath.append(game.gameCode)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .task {
                await game.leaveGame()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore())
}
