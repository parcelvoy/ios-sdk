import UIKit
import Parcelvoy

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let id = "test"// UUID().uuidString
        Parcelvoy.shared.identify(id: id, traits: [
            "first_name": "John",
            "last_name": "Doe"
        ])

        Parcelvoy.shared.track(event: "Application Opened", properties: [ "property": true ])
    }

    @IBAction func registerPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("PV | Notification Status: \(granted)")
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    @IBAction func getNotifications() {
        Parcelvoy.shared.getNofications { result in
            print(result)
            switch result {
            case .failure(let error): print(error)
            case .success(let notifications):
                guard let notification = notifications.results.first else {
                    return
                }
                Parcelvoy.shared.show(notification: notification)
            }
        }
    }
}

