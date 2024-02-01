//
//  WaitingRoomView.swift
//  Telestrations
//
//  Created by Aaron Butler on 1/31/24.
//

import SwiftUI

struct WaitingRoomView: View {
    @EnvironmentObject var game: GameStore
    
    var body: some View {
        VStack {
            Text("GAME CODE: \(game.gameCode)")
            ForEach(game.players.keys.map({ $0 }), id: \.self) { player in
                Text(player)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    game.isShowingDrawingView = true
                } label: {
                    Text("Start!")
                }
                .disabled(game.players.count != 2)
            }
        }
        .fullScreenCover(isPresented: $game.isShowingDrawingView) {
            DrawingView(gameCode: game.gameCode, isShowingDrawingView: $game.isShowingDrawingView)
                .environmentObject(game)
        }
        .onChange(of: game.isShowingDrawingView) { oldValue, newValue in
            if !newValue {
                Task {
                    await game.leaveGame()
                }
            } else {
                Task {
                    await game.alertGameStart()
                }
            }
        }
        .onAppear {
            game.getGameStatus()
        }
        .onChange(of: game.players) { oldValue, newValue in
            
        }
    }
}

#Preview {
    WaitingRoomView()
}
