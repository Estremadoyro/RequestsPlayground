//
//  ViewController.swift
//  RequestsPlayground
//
//  Created by Leonardo  on 2/10/22.
//

import UIKit

final class ViewController: UIViewController {
    private lazy var networkManager = NetworkManager()
    
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
    
    func getPlayer() {
        networkManager.getPlayer { name in
            DispatchQueue.main.async { [weak self] in
                print("senku [DEBUG] \(String(describing: type(of: self))) - Nameee: \(name)")
                self?.playerNameLabel.text = name
            }
        }
    }
}

final class NetworkManager {
    func makeRequest(completion: @escaping (Player?, HTTPURLResponse?, NetworkError?) -> Void) {
        // Create the HTTP Session (URLSession & configure it)
        let httpSessionConfiguration: URLSessionConfiguration = .ephemeral
        let httpSession = URLSession(configuration: httpSessionConfiguration)

        // Create the HTTP Request (URLRequest)
        let urlString: String = "https://lol-friends-server.herokuapp.com/api/v1.1/summoner/la2/runewolf"
        guard let url = URL(string: urlString) else {
            completion(nil, nil, NetworkError.urlError)
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
            if let error = error {
                print("senku [Network] \(String(describing: type(of: self))) - Error: \(error)")
                completion(nil, nil, NetworkError.requestError)
                return
            }

            // Check for response code 200
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, nil, NetworkError.noResponseCode)
                return
            }
            guard httpResponse.statusCode == 200 else {
                print("senku [Network] \(String(describing: type(of: self))) - Server code different:  \((response  as? HTTPURLResponse)?.statusCode ?? 0)")
                completion(nil, httpResponse, NetworkError.responseCodeInvalid)
                return
            }

            // Check for data existing (payload)
            guard let data = data else {
                print("senku [DEBUG] \(String(describing: type(of: self))) - Data error")
                completion(nil, httpResponse, NetworkError.responseDataNil)
                return
            }

            // Decode the data
            do {
                let player = try JSONDecoder().decode(PlayerModel.self, from: data)
                print("senku [DEBUG] \(String(describing: type(of: self))) - Sucessfuly decoded player")
                completion(player.player, httpResponse, nil)
            } catch {
                print("senku [DEBUG] \(String(describing: type(of: self))) - Error")
                completion(nil, httpResponse, NetworkError.decodingError)
            }
        }
        // Run HTTP Task
        httpTask.resume()
    }

    func getPlayer(completion: @escaping (String) -> Void ) {
        let queue = DispatchQueue(label: "estremadoyro.net", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: .global(qos: .userInitiated))
        queue.async { [weak self] in
            guard let self = self else { return }
            self.makeRequest { player, response, error in
                guard error == nil else { return }
                guard response != nil else { return }
                if let player = player {
                    print("senku [DEBUG] \(String(describing: type(of: self))) - player: \(player.summonerName) @ \(player.region)")
                    completion(player.summonerName)
                }
            }
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
enum Result<T> {
    case success(T)
    case error(Error)
}

// MARK: - Model
struct PlayerModel: Decodable {
    var player: Player
}

struct Player: Decodable {
    var summonerName: String
    var region: String

    enum CodingKeys: String, CodingKey {
        case summonerName = "name"
        case region
    }
}
