//
//  DrawingView.swift
//  Telestrations
//
//  Created by Aaron Butler on 1/30/24.
//

import SwiftUI

struct Line: Equatable {
    var points: [CGPoint]
    var color: Color
}

struct DrawingView: View {
    var gameCode: String
    @Binding var isShowingDrawingView: Bool
    
    @State private var lines: [Line] = []
    @State private var selectedColor = Color.orange
    
    @EnvironmentObject var game: GameStore
    
    let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            HStack {
                Text("Round: \(game.round)")
                if game.isDrawing {
                    Text(game.currentWord.uppercased())
                        .bold()
                }
                Text(game.isDrawing ? "Drawing for: \(game.targetPlayer)" : "Guessing for: \(game.targetPlayer)")
            }
            
            if game.isDrawing {
                HStack {
                    ForEach([Color.green, .orange, .blue, .red, .pink, .purple], id: \.self) { color in
                        colorButton(color: color)
                    }
                    clearButton()
                    exitButton()
                }
            }
            
            ZStack {
                Rectangle()
                    .fill(.black)
                Rectangle()
                    .fill(.brown)
                    .frame(width: 310, height: 460)
                    .padding()
                Canvas { ctx, size in
                    for line in lines {
                        var path = Path()
                        path.addLines(line.points)
                        
                        ctx.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 300, height: 450)
                .background(.white)
                .disabled(!game.isDrawing)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged({ value in
                            if game.isDrawing {
                                let position = value.location
                                
                                if value.translation == .zero {
                                    lines.append(Line(points: [position], color: selectedColor))
                                } else {
                                    guard let lastIdx = lines.indices.last else {
                                        return
                                    }
                                    
                                    lines[lastIdx].points.append(position)
                                }
                            }
                        })
                )
                .onReceive(timer) { time in
                    Task {
                        if !game.isDrawing {
                            lines = await game.getData().lines ?? []
                        }
                    }
                }
                .onChange(of: lines) { _, _ in
                    Task {
                        if game.isDrawing {
                            await game.sendData(lines: lines)
                        }
                    }
                }
                .onChange(of: game.round) { oldValue, newValue in
                    lines.removeAll()
                    
                    Task {
                        if game.isDrawing {
                            await game.sendData(lines: lines)
                        }
                    }
                }
            }
            
            if !game.isDrawing {
                HStack {
                    TextField("Guess", text: $game.guess)
                        .frame(maxWidth: .infinity, maxHeight: 80)
                        .multilineTextAlignment(.center)
                        .font(.title)
                    Button {
                        Task {
                            await game.checkGuess()
                            game.guess = ""
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .padding(.trailing)
                    }
                }
                .border(.black, width: 5)
                .padding()
            }
        }
    }
    
    @ViewBuilder
    func colorButton(color: Color) -> some View {
        Button {
            selectedColor = color
        } label: {
            Image(systemName: "circle.fill")
                .font(.largeTitle)
                .foregroundColor(color)
                .mask {
                    Image(systemName: "pencil.tip")
                        .font(.largeTitle)
                }
        }
    }
    
    @ViewBuilder
    func clearButton() -> some View {
        Button {
            lines.removeAll()
            
            Task {
                if game.isDrawing {
                    await game.sendData(lines: lines)
                }
            }
        } label: {
            Image(systemName: "pencil.tip.crop.circle.badge.minus")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    func exitButton() -> some View {
        Button {
            isShowingDrawingView = false
        } label: {
            Image(systemName: "xmark")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    DrawingView(gameCode: "ABC123", isShowingDrawingView: .constant(true))
        .environmentObject(GameStore())
}


extension CGPoint {
    init?(dictionary: [String: CGFloat]) {
        guard let x = dictionary["x"], let y = dictionary["y"] else { return nil }
        self.init(x: x, y: y)
    }
    
    var dictionaryRepresentation: [String: CGFloat] {
        return ["x": self.x, "y": self.y]
    }
}

extension Color {
    init(colorName: String) {
        switch colorName {
        case "green":
            self.init(.green)
        case "orange":
            self.init(.orange)
        case "blue":
            self.init(.blue)
        case "red":
            self.init(.red)
        case "pink":
            self.init(.pink)
        case "purple":
            self.init(.purple)
        default:
            self.init(.green)
        }
    }
}
