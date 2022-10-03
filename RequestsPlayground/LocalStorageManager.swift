//
//  LocalStorageManager.swift
//  RequestsPlayground
//
//  Created by Leonardo  on 2/10/22.
//

import Foundation

struct LocalStorageManager<T: Codable>: LocalStorable {
    typealias Entity = T

    func save(entity: Entity, completion: ((Result<Data, LocalStorageError>) -> Void)? = nil) {
        let storage = UserDefaults.standard

        do {
            let data = try JSONEncoder().encode(entity)
            print("senku [DEBUG] \(String(describing: type(of: self))) - Entity to save: \((entity as? PlayerModel)?.player.summonerName ?? "")")
            storage.set(data, forKey: "key-player")
            print("senku [UserDefaults] \(String(describing: type(of: self))) - Success saving player")
            completion?(.success(data))
        } catch {
            print("senku [UserDefaults] \(String(describing: type(of: self))) - Error saving  player: \(error)")
            completion?(.failure(.encodingError))
        }
    }

    func load(completion: ((Result<Entity, LocalStorageError>) -> Void)? = nil) {
        let storage = UserDefaults.standard
        guard let data = storage.object(forKey: "key-player") as? Data else { completion?(.failure(.dataRetrievingError)); return }
        do {
            let json = try JSONDecoder().decode(T.self, from: data)
            print("senku [UserDefaults] \(String(describing: type(of: self))) - Success loading player")
            completion?(.success(json))
        } catch {
            print("senku [UserDefaults] \(String(describing: type(of: self))) - Error loading player | \(error)")
            completion?(.failure(.decodingError))
        }
    }
    
    func delete() {
        UserDefaults.standard.removeObject(forKey: "key-player")
    }
}

protocol LocalStorable {
    associatedtype Entity: Codable
    func save(entity: Entity, completion: ((Result<Data, LocalStorageError>) -> Void)?)
    func load(completion: ((Result<Entity, LocalStorageError>) -> Void)?)
}

enum LocalStorageError: String, Error {
    case encodingError = "Encoding error"
    case decodingError = "Decoding error"
    case dataRetrievingError = "Error retrieving data form LocalStorage"
}
