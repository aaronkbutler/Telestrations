//
//  GameStore.swift
//  Telestrations
//
//  Created by Aaron Butler on 1/30/24.
//

import FirebaseDatabase
import SwiftUI

@MainActor final class GameStore: ObservableObject {
    @Published var name: String = ""
    @Published var gameCode: String = ""
    @Published var isShowingAlert: Bool = false
    @Published var isShowingWaitingRoom: Bool = false
    @Published var isShowingDrawingView: Bool = false
    
    @Published var players: [String: Int] = [:]
    @Published var round: Int = 0
    
    @Published var guess: String = ""
    @Published var currentWord: String = ""
    
    var isDrawing: Bool {
        guard let myIndex = players.first(where: { $0.key == name })?.value else { return false }
        
        return (myIndex + round) % 2 == 0
    }
    
    var targetPlayer: String {
        guard let myIndex = players.first(where: { $0.key == name })?.value else { return "" }
        
        if myIndex < players.count - 1 {
            return players.first(where: { $0.value == myIndex + 1 })?.key ?? ""
        }
        
        return players.first(where: { $0.value == 0 })?.key ?? ""
    }
    
    func joinGame() async -> Bool {
        let ref = Database.database().reference(withPath: "games")
        do {
            let snapshot = try await ref.getData()
            
            if let dataDict = snapshot.value as? NSDictionary,
               let gameCodes = dataDict.allKeys as? [String],
               gameCodes.contains(where: { $0 == gameCode }),
               let game = dataDict[gameCode] as? NSDictionary {
                let players = game["players"] as? NSDictionary ?? [:]
                
                if !players.allKeys.contains(where: { $0 as? String == name }) {
                    try await ref.child(gameCode).child("players").child(name).setValue(players.allKeys.count)
                    
                    try await ref.child(gameCode).child("players").child(name).onDisconnectRemoveValue()
                    try await ref.child(gameCode).child("lines").child(name).onDisconnectRemoveValue()
                    
                    isShowingWaitingRoom = true
                    
                    return true
                } else {
                    print("name already exists!")
                }
            }
        } catch {
            print("failed to join game")
        }
        
        return false
    }
    
    func startGame() async -> Bool {
        let code = 6.randomAlphanumericString()
        gameCode = code
        
        let ref = Database.database().reference(withPath: "games")
        do {
            try await ref.child(code).setValue(["gameCode": code,
                                                "round": 0,
                                                "players": [name: 0],
                                                "word": wordBank.randomElement() ?? "Helicopter"])
            
            try await ref.child(code).child("players").child(name).onDisconnectRemoveValue()
            try await ref.child(code).child("lines").child(name).onDisconnectRemoveValue()
            
            isShowingWaitingRoom = true
            
            return true
        } catch {
            print("failed to start game")
        }
        
        return false
    }
    
    func leaveGame() async {
        let ref = Database.database().reference(withPath: "games")
        do {
            let snapshot = try await ref.getData()
            
            if let dataDict = snapshot.value as? NSDictionary,
               let gameCodes = dataDict.allKeys as? [String],
               gameCodes.contains(where: { $0 == gameCode }) {
                
                try await ref.child(gameCode).child("players").child(name).removeValue()
            }
        } catch {
            print("failed to join game")
        }
    }
    
    func sendData(lines: [Line]) async {
        let ref = Database.database().reference(withPath: "games")
        do {
            if let dictLines = serializeLinesToJson(lines),
               let jsonObject = try? JSONSerialization.jsonObject(with: dictLines, options: []) {
                try await ref.child(gameCode).child("lines").child(name).setValue(jsonObject)
            }
        } catch {
            print("failed to send data")
        }
    }
    
    func convertLinesToDictionary(_ lines: [Line]) -> [[String: Any]] {
        return lines.map { line in
            return [
                "points": line.points.map { $0.dictionaryRepresentation },
                "color": line.color.description
            ]
        }
    }
    
    func serializeLinesToJson(_ lines: [Line]) -> Data? {
        let dictLines = convertLinesToDictionary(lines)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictLines, options: [])
            return jsonData
        } catch {
            print("Error serializing lines to JSON: \(error)")
            return nil
        }
    }
    
    func getData() async -> (lines: [Line]?, word: String?) {
        let ref = Database.database().reference(withPath: "games").child(gameCode)
        do {
            let snapshot = try await ref.getData()
            
            if let dataDict = snapshot.value as? NSDictionary,
               let lines = dataDict["lines"] as? NSDictionary,
               let linesToDraw = lines[targetPlayer] as? [[String: Any]] {
                return (convertDictionaryToLines(linesToDraw), nil)
            }
        } catch {
            print("failed to join game")
        }
        
        return (nil, nil)
    }
    
    func convertDictionaryToLines(_ dict: [[String: Any]]) -> [Line] {
        return dict.compactMap { lineDict in
            guard let pointDicts = lineDict["points"] as? [[String: CGFloat]],
                  let color = lineDict["color"] as? String else { return Line(points: [], color: .black) }

            let points = pointDicts.compactMap { CGPoint(dictionary: $0) }
            
            return Line(points: points, color: Color(colorName: color))
        }
    }
    
    func getGameStatus() {
        let ref = Database.database().reference(withPath: "games").child(gameCode)
        ref.observe(DataEventType.value, with: { snapshot in
            if let gameData = snapshot.value as? NSDictionary,
               let playerData = gameData["players"] as? NSDictionary {
                self.players = playerData as? [String: Int] ?? [:]
                if let newRound = gameData["round"] as? Int,
                   newRound != self.round {
                    if self.round == 0 {
                        self.isShowingDrawingView = true
                    }
                    self.round = newRound
                }
                self.currentWord = gameData["word"] as? String ?? ""
            }
        })
    }
    
    func alertGameStart() async {
        if round == 0 {
            let ref = Database.database().reference(withPath: "games").child(gameCode)
            do {
                try await ref.child("round").setValue(1)
            } catch {
                print("failed to join game")
            }
        }
    }
    
    func checkGuess() async {
        if guess.lowercased() == currentWord.lowercased() {
            round += 1
            let ref = Database.database().reference(withPath: "games").child(gameCode)
            do {
                try await ref.child("round").setValue(round)
                try await ref.child("word").setValue(wordBank.randomElement() ?? "Helicopter")
            } catch {
                print("failed to update round")
            }
        }
    }
    
    let wordBank: [String] = [
        "Bicycle",
        "Sunflower",
        "Telescope",
        "Butterfly",
        "Sandcastle",
        "Lighthouse",
        "Waterfall",
        "Rainbow",
        "Dragon",
        "Pirate",
        "Snowman",
        "Balloon",
        "Kite",
        "Pizza",
        "Robot",
        "Castle",
        "Volcano",
        "Dinosaur",
        "Guitar",
        "Unicorn",
        "Skateboard",
        "Elephant",
        "Rocket",
        "Cupcake",
        "Jellyfish",
        "Zombie",
        "Vampire",
        "Mermaid",
        "Superhero",
        "Wizard",
        "Treehouse",
        "Spaceship",
        "Doughnut",
        "Giraffe",
        "Banana",
        "Bookshelf",
        "Firework",
        "Penguin",
        "Glasses",
        "Magnet",
        "Cactus",
        "Treasure",
        "Anchor",
        "Parachute",
        "Igloo",
        "Starfish",
        "Comet",
        "Bridge",
        "Lamp",
        "Pyramid",
        "Bicycle",
        "Sunflower",
        "Telescope",
        "Butterfly",
        "Sandcastle",
        "Lighthouse",
        "Waterfall",
        "Rainbow",
        "Dragon",
        "Pirate",
        "Snowman",
        "Balloon",
        "Kite",
        "Pizza",
        "Robot",
        "Castle",
        "Volcano",
        "Dinosaur",
        "Guitar",
        "Unicorn",
        "Skateboard",
        "Elephant",
        "Rocket",
        "Cupcake",
        "Jellyfish",
        "Zombie",
        "Vampire",
        "Mermaid",
        "Superhero",
        "Wizard",
        "Treehouse",
        "Spaceship",
        "Doughnut",
        "Giraffe",
        "Banana",
        "Bookshelf",
        "Firework",
        "Penguin",
        "Glasses",
        "Magnet",
        "Cactus",
        "Treasure",
        "Anchor",
        "Parachute",
        "Igloo",
        "Starfish",
        "Comet",
        "Bridge",
        "Lamp",
        "Pyramid",
        "Windmill",
        "Scarecrow",
        "Sailboat",
        "Campfire",
        "Squirrel",
        "Tornado",
        "Kangaroo",
        "Lightning",
        "Crown",
        "Beehive",
        "Cherry",
        "Owl",
        "Tulip",
        "Globe",
        "Seahorse",
        "Accordion",
        "Broom",
        "Castle",
        "Dartboard",
        "Envelope",
        "Feather",
        "Grapes",
        "Hammock",
        "Iceberg",
        "Juice",
        "Koala",
        "Lemonade",
        "Microphone",
        "Necklace",
        "Octopus",
        "Popcorn",
        "Quilt",
        "Rattlesnake",
        "Submarine",
        "Tiger",
        "Umbrella",
        "Violin",
        "Walrus",
        "Xylophone",
        "Yacht",
        "Acorn",
        "Backpack",
        "Crab",
        "Dolphin",
        "Eclipse",
        "Flamingo",
        "Guitar",
        "Helicopter",
        "Island",
        "Jacket",
        "Keyboard",
        "Lantern",
        "Mushroom",
        "Nest",
        "Ostrich",
        "Pumpkin",
        "Raincoat",
        "Snake",
        "Trophy",
        "Ukulele",
        "Volleyball",
        "X-ray",
        "Yo-yo"
    ]
    
}

extension Int {
    func randomAlphanumericString() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomString = (0..<self).map { _ in String(letters.randomElement() ?? "A")
        }.reduce("", +)
        return randomString
    }
}
