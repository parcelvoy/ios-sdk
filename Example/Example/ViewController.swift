import UIKit
import Parcelvoy

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Parcelvoy.shared.identify(id: UUID().uuidString, traits: [
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
}

