//
//  BombPartyModel.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import Foundation
import UIKit
import FirebaseDatabaseInternal
import FirebaseAuth

protocol GameManagerDelegate: AnyObject {
    func gameManager(_ manager: GameManager, roomStateUpdated room: Room)
    func gameManager(_ manager: GameManager, willShakePlayer playerID: String, at position: Int)
    func gameManager(_ manager: GameManager, playerTurnChanged playerID: String)
    func gameManager(_ manager: GameManager, currentLettersUpdated letters: String)
    func gameManager(_ manager: GameManager, playerWordsUpdated playerWords: [String: String])
    func gameManager(_ manager: GameManager, playerUpdated players: [String: Bool])
}

class GameManager {
//    var game: Game?
    var currentLetters: String = ""
    var playerWords: [String: String] = [:]
    var currentPlayerTurn: String = ""
    var positions: [String: Int] = [:]
    var players: [String: Bool] = [:]

    var room: Room?
    var roomID: String
    
    var service: FirebaseService
    var ref = Database.database().reference()
    weak var delegate: GameManagerDelegate?
    var playerInfos: [String: MyUser] = [:]
        
    init(roomID: String, service: FirebaseService) {
        self.service = service
        self.roomID = roomID
    }
    
    func startGame() {
        // Only room master can start game
        guard let creatorID = room?.creatorID,
              let currentUserID = service.currentUser?.uid
        else { return }
        
        if creatorID == currentUserID {
            ref.updateChildValues([
                "rooms/\(roomID)/status": Room.Status.inProgress.rawValue,
                "games/\(roomID)/currentPlayerTurn": currentUserID  // or random?
            ])
        }
        
    }
    
    func setup() {
        observeRoom()
        observeShakes()
        observePlayerTurn()
        observeCurrentLetters()
        observePlayerWords()
        observePositions()
        observePlayers()
    }
    
    func observePlayerWords() {
        ref.child("games/\(roomID)/playerWords").observe(.value) { [self] snapshot in
            guard let playerWords = snapshot.value as? [String: String] else { return }
            self.playerWords = playerWords
            delegate?.gameManager(self, playerWordsUpdated: playerWords)
        }
    }
    
    
    func observeCurrentLetters() {
        ref.child("games/\(roomID)/currentLetters").observe(.value) { [self] snapshot in
            guard let letters = snapshot.value as? String else { return }
            self.currentLetters = letters
            delegate?.gameManager(self, currentLettersUpdated: letters)
        }
    }
    
    func observePlayerTurn() {
        ref.child("games/\(roomID)/currentPlayerTurn").observe(.value) { [self] snapshot in
            guard let currentPlayerTurn = snapshot.value as? String else { return }
            print("Current Turn: \(currentPlayerTurn)")
            self.currentPlayerTurn = currentPlayerTurn
            delegate?.gameManager(self, playerTurnChanged: currentPlayerTurn)
        }
    }
    
    func observeRoom() {
        ref.child("rooms/\(roomID)").observe(.value) { [self] snapshot in
            guard let updatedRoom = snapshot.toObject(Room.self) else { return }
            room = updatedRoom
            self.delegate?.gameManager(self, roomStateUpdated: updatedRoom)
        }
    }
    
//    Players and Positions: In observePlayers() and observePositions(), you are observing the entire node. If the positions and players change frequently, this can become expensive in terms of bandwidth and Firebase read costs.
//    Optimization: Use .childChanged to observe specific changes rather than downloading the entire set of positions or players every time.
    func observePositions() {
        ref.child("games/\(roomID)/positions").observe(.value) { [self] snapshot in
            guard let positions = snapshot.value as? [String: Int] else { return }
            self.positions = positions
        }
    }
    
    func observePlayers() {
        ref.child("games/\(roomID)/players").observe(.value) { [self] snapshot in
            print("Players changed")
            guard let players = snapshot.value as? [String: Bool] else { return }
            self.players = players
            delegate?.gameManager(self, playerUpdated: players)
        }
    }

    func typing(_ partialWord: String) async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "games/\(roomID)/playerWords/\(currentUser.uid)": partialWord
        ])
    }
    
    func submit(_ word: String) async throws {
        let wordIsValid = word.isWord && word.contains(currentLetters)
        if wordIsValid {
            try await handleSubmitSuccess()
        } else {
            try await handleSubmitFail()
        }
    }
    
    private func handleSubmitSuccess() async throws {
        guard let currentUser = service.currentUser,
              let currentPosition = getPosition(currentUser.uid)
        else { return }
        
        let playerCount = positions.count
        let newLetters = GameManager.generateRandomLetters()
        let nextPosition = (currentPosition + 1) % playerCount
        let isLastTurn = currentPosition == positions.count - 1
        
        guard let nextPlayerUID = (positions.first(where: { $0.value == nextPosition }))?.key else { return }
        
        var updates: [String: Any] = [
            "games/\(roomID)/currentLetters": newLetters,       // create new letters
            "games/\(roomID)/currentPlayerTurn": nextPlayerUID,  // update next players turn
            "games/\(roomID)/playerWords/\(nextPlayerUID)": ""  // reset next player's input
        ]
        
        if isLastTurn {
            updates["games/\(roomID)/rounds"] = ServerValue.increment(1)
        }
        
        try await ref.updateChildValues(updates)
    }
    
    private func handleSubmitFail() async throws {
        guard let currentUser = service.currentUser else { return }
        try await ref.updateChildValues([
            "shake/\(roomID)/players/\(currentUser.uid)": true
        ])
        throw WordError.invalidWord
    }
    
    func observeShakes() {
        ref.child("shake/\(roomID)/players").observe(.value) { [self] snapshot in
            guard let shakePlayers = snapshot.toObject([String: Bool].self) else {
                print("Failed to convert snapshot to shakePlayers")
                return
            }
            for (playerID, shouldShake) in shakePlayers {
                // Don't shake current player using cloud functions (don't want current player to perceive lag, we shake them locally)
                guard shouldShake,
                      let position = getPosition(playerID) else { continue }
                delegate?.gameManager(self, willShakePlayer: playerID, at: position)
            }
        }
    }
    
    func getPosition(_ uid: String?) -> Int? {
        guard let uid = uid else { return nil }
        return positions[uid]
    }

    
    static let commonLetterCombinations = [
        // 2-letter combinations
        "th", "he", "in", "er", "an", "re", "on", "at", "en", "nd", "st", "es", "ng", "ou",
        // 3-letter combinations
        "the", "and", "ing", "ent", "ion", "tio", "for", "ere", "her", "ate", "est", "all", "int", "ter"
    ]
    
    static func generateRandomLetters() -> String {
        return commonLetterCombinations.randomElement()!.uppercased()
    }
    
}
extension GameManager {
    enum WordError: Error {
        case invalidWord
    }
}

extension String {
    var isWord: Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: self.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: self.lowercased(), range: range, startingAt: 0, wrap: false, language: "en")

        return misspelledRange.location == NSNotFound
    }
}

//Reduce Firebase Reads:
//  - Use more targeted listeners (.childAdded, .childChanged) and avoid .value where unnecessary.
//Throttling Updates:
//  - If certain data (like typing() or submit()) is updated very frequently, consider batching those updates or introducing a debounce mechanism to avoid flooding Firebase with writes.
//Error Handling and UI Feedback:
//  - Ensure that all thrown errors are caught and handled appropriately, providing feedback to the user (especially for invalid word submissions).
//Use Transactions for Critical Data:
//  - For game-critical data like currentPlayerTurn or the number of rounds, transactions would ensure that updates happen atomically and without conflict.