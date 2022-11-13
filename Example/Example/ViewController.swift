import UIKit
import Parcelvoy

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: Enter API Key and URL
        let apiKey = ""
        let urlEndpoint = ""

        let pv = Parcelvoy.shared
        pv.initialize(apiKey: apiKey, urlEndpoint: urlEndpoint)

        pv.identify(id: UUID().uuidString, traits: [
            "first_name": "John",
            "last_name": "Doe"
        ])

        pv.track(event: "Application Opened", properties: [ "property": true ])
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
}

