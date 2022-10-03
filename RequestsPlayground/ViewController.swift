//
//  ViewController.swift
//  RequestsPlayground
//
//  Created by Leonardo  on 2/10/22.
//

import UIKit

final class ViewController: UIViewController {
    private lazy var networkManager = NetworkManager()
    private lazy var localStorageManager = LocalStorageManager<PlayerModel>()

    private lazy var playerNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.black
        label.text = "Loading..."
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 24)
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 10
        view.addSubview(label)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        getPlayer()
//        if let appDomain = Bundle.main.bundleIdentifier {
//            UserDefaults.standard.removePersistentDomain(forName: appDomain)
//        }
    }

    func configureUI() {
        view.backgroundColor = UIColor.systemPurple
        NSLayoutConstraint.activate([
            playerNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerNameLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playerNameLabel.heightAnchor.constraint(equalToConstant: 100),
            playerNameLabel.widthAnchor.constraint(equalToConstant: 250)
        ])
    }

    func updateLabel(name: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playerNameLabel.text = name
        }
    }

    func getPlayer() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.underlyingQueue = .global(qos: .userInitiated)
        queue.addOperation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.localStorageManager.load { result in
                switch result {
                    // Found player in LocalStorage
                    case .success(let model):
                        print("senku [DEBUG] \(String(describing: type(of: strongSelf))) - Player found in local storage: \(model.player)")
                        strongSelf.updateLabel(name: model.player.summonerName)
                    // Not found player in LocalStorage
                    case .failure(let error):
                        print("senku [DEBUG] \(String(describing: type(of: strongSelf))) - Player not found in local: \(error)")
                        strongSelf.networkManager.getPlayer { model in
                            print("senku [DEBUG] \(String(describing: type(of: strongSelf))) - Player found from network request: \(model.player.summonerName)")
                            strongSelf.updateLabel(name: model.player.summonerName)
                            strongSelf.localStorageManager.save(entity: model)
                        }
                }
            }
        }
    }
}

final class NetworkManager {
    func makeRequest(completion: @escaping (CustomResult<PlayerModel, NetworkError>) -> Void) {
        // Create the HTTP Session (URLSession & configure it)
        let httpSessionConfiguration: URLSessionConfiguration = .ephemeral
        let httpSession = URLSession(configuration: httpSessionConfiguration)

        // Create the HTTP Request (URLRequest)
        let urlString: String = "https://lol-friends-server.herokuapp.com/api/v1.1/summoner/la2/runewolf"
        guard let url = URL(string: urlString) else {
            completion(.error(.urlError))
            return
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "GET"
        httpRequest.networkServiceType = .responsiveData
        httpRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        // Configure the URL (URLComponents). Not really necessary as my API doesn't support parameters, it should tho ...
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems?.append(contentsOf: [
            URLQueryItem(name: "summonerName", value: "runewolf"),
            URLQueryItem(name: "region", value: "la1")
        ])
        httpRequest.url = urlComponents?.url

        // Create the HTTP Task
        let httpTask = httpSession.dataTask(with: httpRequest) { data, response, error in
            // Check if there was an error (Front-end)
            guard error == nil else { completion(.error(.requestError)); return }

            // Check for response code 200
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.error(.noResponseCode))
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.error(.responseCodeInvalid))
                return
            }

            // Check for data existing (payload)
            guard let data = data else {
                completion(.error(.responseDataNil))
                return
            }

            // Decode the data
            do {
                let player = try JSONDecoder().decode(PlayerModel.self, from: data)
                completion(.success(player))
            } catch {
                completion(.error(.decodingError))
            }
        }
        // Run HTTP Task
        httpTask.resume()
    }

    func getPlayer(completion: @escaping (PlayerModel) -> Void) {
        let queue = DispatchQueue(label: "estremadoyro.net", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: .global(qos: .userInitiated))
        queue.async { [weak self] in
            guard let self = self else { return }
            self.makeRequest { result in
                switch result {
                    case .success(let model):
                        print("senku [DEBUG] \(String(describing: type(of: self))) - player: \(model.player.summonerName) @ \(model.player.region) | level: \(model.player.level) | ranks: \(model.player.ranks.compactMap { "\($0.league.rawValue) \($0.division.rawValue)" })")
                        completion(model)
                    case .error(let error):
                        print("senku [DEBUG] \(String(describing: type(of: self))) - error: \(error.rawValue)")
                }
            }
        }
    }

    func callDog(dogResponse: ((String) -> String) -> String) -> String {
        print("Do some stuff")
        return dogResponse { response in
            "Dog said: \(response)"
        }
    }

    func dogMain() -> String {
        return callDog { closure in
            let response: String = closure("")
            return response
        }
    }
}

// MARK: Error message
enum NetworkError: String, Error {
    case responseCodeInvalid = "Invalid response code"
    case requestError = "Erorr making request"
    case responseDataNil = "Respones data is nil"
    case urlError = "Url couldn't be created from string"
    case decodingError = "Error decoding data into model"
    case noResponseCode = "No reponse code found from request"
}

// MARK: Result
@frozen enum CustomResult<Success, Failure: Error> {
    case success(Success)
    case error(Failure)
}

// MARK: - Model
struct PlayerModel: Codable {
    let player: Player

    enum CodingKeys: String, CodingKey {
        case player
    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        player = try container.decode(Player.self, forKey: .player)
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(player, forKey: .player)
//    }
}

struct Player: Codable {
    let summonerName: String
    let region: Region
    let level: Int
    let ranks: [PlayerRank]
    let elo: Int // Might not be present, use decodeIfPresent or decode() will throw an error
    let queue: Queue

    enum CodingKeys: String, CodingKey {
        case summonerName = "name"
        case region
        case level = "summonerLevel"
        case ranks = "summonerRank"
        case elo
        case queue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summonerName = try container.decode(String.self, forKey: .summonerName)
        region = try container.decode(Region.self, forKey: .region)
        level = try container.decode(Int.self, forKey: .level)
        ranks = try container.decode([PlayerRank].self, forKey: .ranks)
        elo = try container.decodeIfPresent(Int.self, forKey: .elo) ?? 800
        queue = try container.decodeIfPresent(Queue.self, forKey: .queue) ?? .other("regular")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summonerName, forKey: .summonerName)
        try container.encode(region, forKey: .region)
        try container.encode(level, forKey: .level)
        try container.encode(ranks, forKey: .ranks)
        try container.encodeIfPresent(elo, forKey: .elo)
        try container.encodeIfPresent(queue, forKey: .queue)
    }
}

struct PlayerRank: Codable {
    var league: League
    var division: Division
    var promos: Promos

    enum CodingKeys: String, CodingKey {
        case league, division, promos
    }
}

struct Promos: Codable {
    let isInPromo: Bool

    enum CodingKeys: CodingKey {
        case isInPromo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isInPromo = try container.decodeIfPresent(Bool.self, forKey: .isInPromo) ?? false
    }
}

enum Region: String, Codable {
//    case lan = "la1"
//    case las = "la2"
//    case na = "na1"
    case lan, las, na
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
            case "la1": self = .lan
            case "la2": self = .las
            case "na1": self = .na
            default: self = .other
        }
    }
}

enum League: String, Codable {
    typealias RawValue = String
    case iron
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case master
    case grandMaster = "grand_master"
    case challenger

    init?(_ number: Int) {
        switch number {
            case 0: self = .iron
            case 1: self = .bronze
            case 2: self = .silver
            case 3: self = .gold
            case 4: self = .platinum
            case 5: self = .diamond
            case 6: self = .master
            case 7: self = .grandMaster
            case 8: self = .challenger
            default: return nil
        }
    }
}

enum Division: String, Codable {
    case I, II, III, IV
}

enum Queue: Codable {
    case winners
    case lossers
    case other(String)
    // What if something else is sent by back? Like .regular, .new, etc ...
    init(from decoder: Decoder) throws {
        let singleContainer = try decoder.singleValueContainer()
        let value = try singleContainer.decode(String.self) // This can be any String!
        switch value {
            case "winners": self = .winners
            case "lossers": self = .lossers
            default: self = .other(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var singleContainer = encoder.singleValueContainer()
        var value = ""
        switch self {
            case .winners: value = "winners"
            case .lossers: value = "lossers"
            case .other(let otherQueue): value = otherQueue
        }
        try singleContainer.encode(value)
    }
}
