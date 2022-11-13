import UIKit
import Parcelvoy

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let apiKey = "pk_3f45d77c-4581-11ed-8b0b-0242ac110002"
        let urlEndpoint = "https://99dc474bf639.ngrok.io"

        let pv = Parcelvoy.shared
        pv.initialize(apiKey: apiKey, urlEndpoint: urlEndpoint)

        pv.identify(id: UUID().uuidString, traits: [
            "first_name": "John",
            "last_name": "Doe"
        ])

        pv.track()
    }
}

