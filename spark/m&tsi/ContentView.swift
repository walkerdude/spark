
import SwiftUI
import CoreNFC
import UIKit
import CoreLocation
import MapKit
// Models and User Manager
struct InterestsModel: Codable {
    var academicInterests: [String]
    var sportsInterests: [String]
    var mediaInterests: [String]
    
    static let defaultModel = InterestsModel(academicInterests: ["Math", "Science"], sportsInterests: ["Football", "Basketball"], mediaInterests: ["Movies", "Music"])
}
struct UserProfile: Codable, Identifiable {
    var id = UUID()
    var username: String
    var password: String
    var bio: String
    var interests: InterestsModel = InterestsManager.defaultInterests()
    var connections: [Connection] = []
    
    var connectionCount: Int {
        return connections.count
    }
}
struct Connection: Codable, Identifiable, Hashable {
    var id = UUID()
    var username: String
    var date: Date
    var photo: Data?
    var location: CLLocationCoordinate2D?
    // Custom Codable implementation for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case date
        case photo
        case latitude
        case longitude
    }
    init(username: String, date: Date, photo: Data? = nil, location: CLLocationCoordinate2D? = nil) {
        self.username = username
        self.date = date
        self.photo = photo
        self.location = location
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        date = try container.decode(Date.self, forKey: .date)
        photo = try container.decodeIfPresent(Data.self, forKey: .photo)
        if let latitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            location = nil
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(photo, forKey: .photo)
        if let location = location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
    // Custom Equatable implementation
    static func == (lhs: Connection, rhs: Connection) -> Bool {
        return lhs.id == rhs.id &&
            lhs.username == rhs.username &&
            lhs.date == rhs.date &&
            lhs.photo == rhs.photo &&
            lhs.location?.latitude == rhs.location?.latitude &&
            lhs.location?.longitude == rhs.location?.longitude
    }
    // Custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(username)
        hasher.combine(date)
        hasher.combine(photo)
        if let location = location {
            hasher.combine(location.latitude)
            hasher.combine(location.longitude)
        }
    }
}
struct CategoryWrapper: Identifiable {
    let id = UUID()
    let category: String
}
class InterestsManager: ObservableObject {
    @Published var interests: InterestsModel {
        didSet {
            saveInterests()
            print("Interests updated: \(interests)")
        }
    }
    
    private var currentUser: UserProfile?
    
    init() {
        self.interests = InterestsManager.defaultInterests()
    }
    
    func setUser(_ user: UserProfile) {
        self.currentUser = user
        self.interests = InterestsManager.loadInterests(for: user.username) ?? user.interests
    }
    
    func saveInterests() {
        guard let currentUser = currentUser, let encoded = try? JSONEncoder().encode(interests) else { return }
        UserDefaults.standard.set(encoded, forKey: "InterestsData_\(currentUser.username)")
    }
    
    static func loadInterests(for username: String) -> InterestsModel? {
        guard let savedData = UserDefaults.standard.data(forKey: "InterestsData_\(username)"),
              let decodedData = try? JSONDecoder().decode(InterestsModel.self, from: savedData) else {
            return nil
        }
        return decodedData
    }
    
    static func defaultInterests() -> InterestsModel {
        return InterestsModel.defaultModel
    }
    
    func getCurrentInterests() -> InterestsModel {
        return self.interests
    }
}
class UserManager: ObservableObject {
    static let shared: UserManager = {
        let instance = UserManager()
        print("UserManager.shared instance created")
        return instance
    }()
    
    @Published var profiles: [UserProfile] {
        didSet {
            saveProfiles()
        }
    }
    
    @Published var currentUser: UserProfile? {
        didSet {
            if let currentUser = currentUser {
                interestsManager.setUser(currentUser)
                print("Current user set: \(currentUser.username)")
            } else {
                print("Current user is nil")
            }
        }
    }
    
    @Published var interestsManager = InterestsManager()
    
    public init() {
        self.profiles = UserManager.loadProfiles() ?? []
        print("UserManager initialized with profiles: \(self.profiles.count)")
    }
    
    func addProfile(username: String, password: String, bio: String) {
        let newProfile = UserProfile(username: username, password: password, bio: bio)
        profiles.append(newProfile)
        saveProfiles()
    }
    
    func authenticate(username: String, password: String) -> Bool {
        if let profile = profiles.first(where: { $0.username == username && $0.password == password }) {
            currentUser = profile
            print("User authenticated: \(username)")
            return true
        }
        print("Authentication failed for user: \(username)")
        return false
    }
    
    func deleteCurrentUser() {
        if let currentUser = currentUser, let index = profiles.firstIndex(where: { $0.id == currentUser.id }) {
            profiles.remove(at: index)
            self.currentUser = nil
            saveProfiles()
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "UserProfiles")
        }
    }
    
    private static func loadProfiles() -> [UserProfile]? {
        if let savedData = UserDefaults.standard.data(forKey: "UserProfiles"),
           let decodedData = try? JSONDecoder().decode([UserProfile].self, from: savedData) {
            return decodedData
        }
        return nil
    }
    
    func addConnection(username: String, photo: Data?, location: CLLocationCoordinate2D?) {
        let connection = Connection(username: username, date: Date(), photo: photo, location: location)
        if let currentUserIndex = profiles.firstIndex(where: { $0.username == currentUser?.username }) {
            profiles[currentUserIndex].connections.append(connection)
            currentUser = profiles[currentUserIndex] // Update currentUser
            saveProfiles()
        }
    }
    
    func updateCurrentUserInterests(interests: InterestsModel) {
        if let currentUserIndex = profiles.firstIndex(where: { $0.username == currentUser?.username }) {
            profiles[currentUserIndex].interests = interests
            currentUser = profiles[currentUserIndex] // Update currentUser
            saveProfiles()
        }
    }
}
// NFCReaderViewController
protocol NFCReaderDelegate: AnyObject {
    func didDetectSharedInterests(username: String, sharedInterests: [String])
}
class NFCReaderViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    var nfcSession: NFCNDEFReaderSession?
    weak var delegate: NFCReaderDelegate?
    var messageToWrite: NFCNDEFMessage?
    var interestsManager: InterestsManager?
    var username: String?
    var userManager: UserManager?
    var nfcTagData: InterestsModel?
    var nfcTagUsername: String?
    
    func startNFCSession(userManager: UserManager) {
        self.userManager = userManager
        invalidateNFCSession()
        
        guard NFCNDEFReaderSession.readingAvailable else {
            showAlert(message: "NFC reading is not available on this device.")
            return
        }
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        nfcSession?.alertMessage = "Hold your iPhone near the NFC tag to read its content."
        nfcSession?.begin()
        
        print("NFC session started")
    }
    
    func startNFCWriteSession(username: String, interestsManager: InterestsManager) {
        invalidateNFCSession()
        
        guard NFCNDEFReaderSession.readingAvailable else {
            showAlert(message: "NFC reading is not available on this device.")
            return
        }
        
        self.username = username
        self.interestsManager = interestsManager
        
        let interests = interestsManager.getCurrentInterests()
        let messageString = """
        Username: \(username)
        Academic Interests: \(interests.academicInterests.joined(separator: ", "))
        Sports Interests: \(interests.sportsInterests.joined(separator: ", "))
        Media Interests: \(interests.mediaInterests.joined(separator: ", "))
        """
        
        print("Writing message: \(messageString)")
        guard let messageData = messageString.data(using: .utf8) else { return }
        let payload = NFCNDEFPayload(format: .nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data(), payload: messageData)
        let message = NFCNDEFMessage(records: [payload])
        self.messageToWrite = message
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near the NFC tag to write its content."
        nfcSession?.begin()
        
        print("NFC write session started")
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("NFC session did become active.")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                print("User canceled the session.")
            case .readerSessionInvalidationErrorSessionTimeout:
                print("Session timeout.")
            default:
                print("Session invalidation error: \(readerError.localizedDescription)")
            }
        } else {
            print("Session invalidation error: \(error.localizedDescription)")
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                print("Record type: \(record.type)")
                if let payloadString = String(data: record.payload, encoding: .utf8) {
                    print("NFC Tag Payload: \(payloadString)")
                    parseNFCData(payloadString)
                } else {
                    print("NFC Tag Payload could not be decoded.")
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tag is detected. Please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "Failed to detect any tags.")
            return
        }
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Unable to connect to tag: \(error.localizedDescription)")
                return
            }
            tag.queryNDEFStatus { ndefStatus, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Unable to query the NDEF status of tag: \(error!.localizedDescription)")
                    return
                }
                switch ndefStatus {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant.")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read only.")
                case .readWrite:
                    if let message = self.messageToWrite {
                        tag.writeNDEF(message) { error in
                            if let error = error {
                                session.invalidate(errorMessage: "Write NDEF message failed: \(error.localizedDescription)")
                            } else {
                                session.alertMessage = "Write NDEF message successful."
                                print("Write NDEF message successful.")
                            }
                            session.invalidate()
                        }
                    } else {
                        tag.readNDEF { message, error in
                            if let error = error {
                                session.invalidate(errorMessage: "Read NDEF message failed: \(error.localizedDescription)")
                                return
                            }
                            if let message = message {
                                self.readerSession(session, didDetectNDEFs: [message])
                            } else {
                                session.invalidate(errorMessage: "No NDEF message found.")
                            }
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown NDEF tag status.")
                }
            }
        }
    }
    
    private func parseNFCData(_ payloadString: String) {
        let components = payloadString.split(separator: "\n").map { $0.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) } }
        var detectedUsername = ""
        var detectedAcademicInterests: [String] = []
        var detectedSportsInterests: [String] = []
        var detectedMediaInterests: [String] = []
        
        for component in components {
            if component.count == 2 {
                let key = component[0]
                let value = component[1]
                switch key {
                case "Username":
                    detectedUsername = value
                case "Academic Interests":
                    detectedAcademicInterests = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                case "Sports Interests":
                    detectedSportsInterests = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                case "Media Interests":
                    detectedMediaInterests = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                default:
                    break
                }
            }
        }
        
        if !detectedUsername.isEmpty {
            nfcTagUsername = detectedUsername
            nfcTagData = InterestsModel(academicInterests: detectedAcademicInterests, sportsInterests: detectedSportsInterests, mediaInterests: detectedMediaInterests)
            print("NFC Tag Data saved: Username: \(detectedUsername), Interests: \(nfcTagData!)")
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    self.showConnectionPrompt(username: detectedUsername, interests: self.nfcTagData!)
                }
            }
        }
    }
    
    private func showConnectionPrompt(username: String, interests: InterestsModel) {
        guard let currentUser = userManager?.currentUser else {
            print("Error: No current user found in NFCReaderViewController. UserManager.shared.currentUser is nil")
            showAlert(message: "No current user found.")
            return
        }
        
        let currentInterests = userManager?.interestsManager.getCurrentInterests() ?? currentUser.interests
        let sharedAcademicInterests = currentInterests.academicInterests.filter { interests.academicInterests.contains($0) }
        let sharedSportsInterests = currentInterests.sportsInterests.filter { interests.sportsInterests.contains($0) }
        let sharedMediaInterests = currentInterests.mediaInterests.filter { interests.mediaInterests.contains($0) }
        let sharedInterests = sharedAcademicInterests + sharedSportsInterests + sharedMediaInterests
        
        if sharedInterests.isEmpty {
            showAlert(message: "No shared interests found.")
            return
        }
        
        // Show full-page view
        let connectionVC = ConnectionViewController(username: username, sharedInterests: sharedInterests) { [weak self] result in
            switch result {
            case .connect(let photo, let location):
                self?.userManager?.addConnection(username: username, photo: photo, location: location)
            case .cancel:
                break
            }
            self?.dismiss(animated: true, completion: nil)
        }
        if let topController = UIApplication.shared.windows.first?.rootViewController {
            topController.present(connectionVC, animated: true, completion: nil)
        }
    }
    
    public func invalidateNFCSession() {
        nfcSession?.invalidate()
        nfcSession = nil
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
// ConnectionViewController
class ConnectionViewController: UIViewController {
    var username: String
    var sharedInterests: [String]
    var completion: (ConnectionResult) -> Void
    var locationManager: CLLocationManager?
    var photo: Data?
    var location: CLLocationCoordinate2D?
    
    enum ConnectionResult {
        case connect(photo: Data?, location: CLLocationCoordinate2D?)
        case cancel
    }
    
    init(username: String, sharedInterests: [String], completion: @escaping (ConnectionResult) -> Void) {
        self.username = username
        self.sharedInterests = sharedInterests
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Connect with \(username)?"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let sharedInterestsLabel = UILabel()
        sharedInterestsLabel.text = "Shared Interests:"
        sharedInterestsLabel.font = UIFont.systemFont(ofSize: 18)
        sharedInterestsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let sharedInterestsList = UILabel()
        sharedInterestsList.text = sharedInterests.joined(separator: ", ")
        sharedInterestsList.font = UIFont.systemFont(ofSize: 16)
        sharedInterestsList.numberOfLines = 0
        sharedInterestsList.translatesAutoresizingMaskIntoConstraints = false
        
        let takeSelfieButton = UIButton(type: .system)
        takeSelfieButton.setTitle("Take Selfie", for: .normal)
        takeSelfieButton.addTarget(self, action: #selector(takeSelfie), for: .touchUpInside)
        takeSelfieButton.translatesAutoresizingMaskIntoConstraints = false
        
        let pinLocationButton = UIButton(type: .system)
        pinLocationButton.setTitle("Pin Location", for: .normal)
        pinLocationButton.addTarget(self, action: #selector(pinLocation), for: .touchUpInside)
        pinLocationButton.translatesAutoresizingMaskIntoConstraints = false
        
        let connectButton = UIButton(type: .system)
        connectButton.setTitle("Connect", for: .normal)
        connectButton.addTarget(self, action: #selector(connect), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, sharedInterestsLabel, sharedInterestsList, takeSelfieButton, pinLocationButton, connectButton, cancelButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @objc func takeSelfie() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.modalPresentationStyle = .fullScreen
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func pinLocation() {
        let locationPickerVC = LocationPickerViewController()
        locationPickerVC.completion = { [weak self] location in
            self?.location = location
            locationPickerVC.dismiss(animated: true, completion: nil)
        }
        present(locationPickerVC, animated: true, completion: nil)
    }
    
    @objc func connect() {
        completion(.connect(photo: photo, location: location))
    }
    
    @objc func cancel() {
        completion(.cancel)
    }
}
extension ConnectionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage {
            photo = image.jpegData(compressionQuality: 0.8)
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 25
            view.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -150)
            ])
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
// LocationPickerViewController
class LocationPickerViewController: UIViewController, MKMapViewDelegate {
    var mapView: MKMapView!
    var completion: ((CLLocationCoordinate2D) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        view.addSubview(mapView)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("PIN WHERE YOU MET", for: .normal)
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
        ])
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(annotation)
            completion?(coordinate)
        }
    }
    
    @objc func done() {
        if let coordinate = mapView.annotations.first?.coordinate {
            completion?(coordinate)
        }
        dismiss(animated: true, completion: nil)
    }
}
// SwiftUI Views
struct InterestCategoryView: View {
    let category: String
    @Binding var interests: [String]
    let color: Color
    
    var body: some View {
        VStack {
            Text(category)
                .font(.headline)
                .padding(.top)
                .foregroundColor(color)
            ScrollView {
                VStack {
                    ForEach(interests, id: \.self) { interest in
                        Text(interest)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(color.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.vertical, 2)
                    }
                }
            }
            .frame(height: 250)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal, 2)
    }
}
struct EditInterestsView: View {
    let category: String
    @Binding var interests: [String]
    @State private var newInterest = ""
    @EnvironmentObject var interestsManager: InterestsManager
    
    var body: some View {
        VStack {
            Text("Edit \(category) Interests")
                .font(.headline)
                .padding()
            TextField("New Interest", text: $newInterest)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            Button(action: {
                if (!newInterest.isEmpty && !interests.contains(newInterest)) {
                    interests.append(newInterest)
                    interestsManager.saveInterests()
                    print("Added new interest: \(newInterest)")
                    newInterest = ""
                }
            }) {
                Text("Add Interest")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .padding()
            List {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                }
                .onDelete { indexSet in
                    let removedInterests = indexSet.map { interests[$0] }
                    interests.remove(atOffsets: indexSet)
                    interestsManager.saveInterests()
                    print("Removed interests: \(removedInterests)")
                }
            }
        }
        .padding()
    }
}
struct CategorySelectionView: View {
    @EnvironmentObject var interestsManager: InterestsManager
    @Binding var selectedCategory: CategoryWrapper?
    @Binding var isAdding: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(isAdding ? "Select Category to Add" : "Select Category to Remove")
                .font(.headline)
                .padding()
            ForEach([CategoryWrapper(category: "Academic"), CategoryWrapper(category: "Sports"), CategoryWrapper(category: "Media")]) { categoryWrapper in
                Button(action: {
                    selectedCategory = categoryWrapper
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(categoryWrapper.category)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(categoryColor(for: categoryWrapper.category))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Academic":
            return .red
        case "Sports":
            return .green
        case "Media":
            return .purple
        default:
            return .gray
        }
    }
}
struct ConnectionsView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var newConnection = ""
    
    var body: some View {
        VStack {
            TextField("Add new connection", text: $newConnection)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            Button(action: {
                if !newConnection.isEmpty {
                    userManager.addConnection(username: newConnection, photo: nil, location: nil)
                    newConnection = ""
                }
            }) {
                Text("Add Connection")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .padding()
            
            List {
                ForEach(userManager.currentUser?.connections ?? [], id: \.self) { connection in
                    HStack {
                        Text(connection.username)
                        if let location = connection.location {
                            Spacer()
                            Text("Location: \(location.latitude), \(location.longitude)")
                        }
                        if let photoData = connection.photo, let uiImage = UIImage(data: photoData) {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 10)
                        }
                    }
                }
                .onDelete { indexSet in
                    if let currentUserIndex = userManager.profiles.firstIndex(where: { $0.username == userManager.currentUser?.username }) {
                        userManager.profiles[currentUserIndex].connections.remove(atOffsets: indexSet)
                        userManager.saveProfiles()
                    }
                }
            }
        }
        .navigationBarTitle("Connections", displayMode: .inline)
    }
}
struct LeaderboardView: View {
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        VStack {
            List(userManager.profiles.sorted(by: { $0.connectionCount > $1.connectionCount })) { profile in
                HStack {
                    Text(profile.username)
                    Spacer()
                    Text("\(profile.connectionCount) connections")
                }
            }
        }
        .navigationBarTitle("Leaderboard", displayMode: .inline)
    }
}
struct ConnectionsMapView: View {
    var connections: [Connection]
    @Environment(\.presentationMode) var presentationMode
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of the USA
        span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 30.0)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: connections + [Connection(username: "ExampleUser", date: Date(), photo: UIImage(named: "exampleSelfie")?.jpegData(compressionQuality: 0.8), location: CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652))]) { connection in
                MapAnnotation(coordinate: connection.location ?? CLLocationCoordinate2D()) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                        if let photoData = connection.photo, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 10)
                            Text(connection.username)
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .navigationBarTitle("Connections Map", displayMode: .inline)
            
            VStack {
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Exit Map")
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }
        }
    }
}
struct ConnectionPromptView: View {
    var username: String
    var sharedInterests: [String]
    var onConnect: (Data?, CLLocationCoordinate2D?) -> Void
    var onCancel: () -> Void
    @State private var photo: Data?
    @State private var location: CLLocationCoordinate2D?
    @State private var showPhotoPicker = false
    @State private var showLocationPicker = false
    @State private var locationManager = CLLocationManager()
    
    var body: some View {
        VStack {
            Text("Connect with \(username)?")
                .font(.headline)
                .padding()
            Text("Shared Interests:")
                .font(.subheadline)
                .padding(.top)
            List(sharedInterests, id: \.self) { interest in
                Text(interest)
            }
            HStack {
                Button(action: {
                    showPhotoPicker = true
                }) {
                    Text("Take Selfie")
                        .foregroundColor(.blue)
                }
                .padding()
                if let photo = photo, let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 10)
                }
                Button(action: {
                    showLocationPicker = true
                }) {
                    Text("Pin Location")
                        .foregroundColor(.blue)
                }
                .padding()
            }
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(.red)
                }
                .padding()
                Button(action: {
                    onConnect(photo, location)
                }) {
                    Text("Connect")
                        .foregroundColor(.green)
                }
                .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
        .padding()
        .sheet(isPresented: $showPhotoPicker) {
            ImagePicker(sourceType: .camera) { image in
                photo = image.jpegData(compressionQuality: 0.8)
                showPhotoPicker = false
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerViewControllerRepresentable { coordinate in
                location = coordinate
                showLocationPicker = false
            }
        }
    }
}
struct LocationPickerViewControllerRepresentable: UIViewControllerRepresentable {
    var completion: (CLLocationCoordinate2D) -> Void
    
    func makeUIViewController(context: Context) -> LocationPickerViewController {
        let viewController = LocationPickerViewController()
        viewController.completion = completion
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: LocationPickerViewController, context: Context) {}
}
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var completion: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            picker.dismiss(animated: true, completion: nil)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
        }
    }
}
class HomeViewNFCDelegate: NSObject, NFCReaderDelegate {
    private let completion: (String, [String]) -> Void
    
    init(completion: @escaping (String, [String]) -> Void) {
        self.completion = completion
    }
    
    func didDetectSharedInterests(username: String, sharedInterests: [String]) {
        completion(username, sharedInterests)
    }
}
struct NFCReaderViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var detectedUsername: Binding<String>
    var sharedInterests: Binding<[String]>
    var interestsManager: InterestsManager
    var username: String
    var onConnect: (String) -> Void
    var isWriting: Bool
    var userManager: UserManager
    
    func makeUIViewController(context: Context) -> NFCReaderViewController {
        let viewController = NFCReaderViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: NFCReaderViewController, context: Context) {
        if isPresented {
            if isWriting {
                uiViewController.startNFCWriteSession(username: username, interestsManager: interestsManager)
            } else {
                uiViewController.startNFCSession(userManager: userManager)
            }
        } else {
            uiViewController.invalidateNFCSession()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NFCReaderDelegate {
        var parent: NFCReaderViewControllerRepresentable
        
        init(_ parent: NFCReaderViewControllerRepresentable) {
            self.parent = parent
        }
        
        func didDetectSharedInterests(username: String, sharedInterests: [String]) {
            parent.detectedUsername.wrappedValue = username
            parent.sharedInterests.wrappedValue = sharedInterests
            parent.isPresented = false
            parent.onConnect(username)
        }
    }
}
struct SignUpLoginView: View {
    @Binding var isSignedIn: Bool
    @EnvironmentObject var userManager: UserManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var bio: String = ""
    @State private var isLoginMode: Bool = true
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            // Orange background
            Color.orange
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                Text(isLoginMode ? "Login" : "Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                VStack(spacing: 20) {
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    
                    if !isLoginMode {
                        TextField("Bio", text: $bio)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                    }
                }
                
                Button(action: {
                    if isLoginMode {
                        if userManager.authenticate(username: username, password: password) {
                            isSignedIn = true
                        } else {
                            showError = true
                        }
                    } else {
                        userManager.addProfile(username: username, password: password, bio: bio)
                        userManager.authenticate(username: username, password: password)
                        isSignedIn = true
                    }
                }) {
                    Text(isLoginMode ? "Login" : "Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(username.isEmpty || password.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(username.isEmpty || password.isEmpty)
                
                if showError {
                    Text("Invalid username or password")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                        .padding(.top, 10)
                }
                
                Spacer()
                
                Button(action: {
                    isLoginMode.toggle()
                }) {
                    Text(isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Login")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
}
struct MenuView: View {
    @Binding var isSignedIn: Bool
    @Binding var showConnectionsMap: Bool
    @EnvironmentObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var showNFCWriter = false
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: ConnectionsView().environmentObject(userManager)) {
                    Text("Existing Connections")
                }
                NavigationLink(destination: LeaderboardView().environmentObject(userManager)) {
                    Text("Leaderboard")
                }
                Button(action: {
                    showConnectionsMap = true
                }) {
                    Text("Connections Map")
                }
                Button(action: {
                    userManager.currentUser = nil
                    isSignedIn = false
                }) {
                    Text("Log Out")
                        .foregroundColor(.red)
                }
                Button(action: {
                    showAlert = true
                }) {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Delete Account"),
                        message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            userManager.deleteCurrentUser()
                            isSignedIn = false
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
                Button(action: {
                    showNFCWriter = true
                }) {
                    Text("Update NFC Tag")
                        .foregroundColor(.blue)
                }
            }
            .navigationBarTitle("Menu", displayMode: .inline)
            .sheet(isPresented: $showNFCWriter) {
                if let currentUser = userManager.currentUser {
                    NFCReaderViewControllerRepresentable(
                        isPresented: $showNFCWriter,
                        detectedUsername: .constant(currentUser.username),
                        sharedInterests: .constant([]),
                        interestsManager: userManager.interestsManager,
                        username: currentUser.username,
                        onConnect: { _ in
                            // Handle the connect action if needed
                        },
                        isWriting: true,
                        userManager: userManager
                    )
                }
            }
        }
    }
}
struct HomeView: View {
    @Binding var isSignedIn: Bool
    var username: String
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var interestsManager: InterestsManager
    @Binding var showConnectionPrompt: Bool
    @Binding var detectedUsername: String
    @Binding var sharedInterests: [String]
    @State private var showCategorySelection = false
    @State private var isAddingInterest = true
    @State private var selectedCategory: CategoryWrapper? = nil
    @State private var showProfile = false
    @State private var showMenu = false
    @State private var showConnectionsMap = false
    var body: some View {
        ZStack {
            VStack {
                Rectangle()
                    .fill(Color.orange)
                    .frame(height: UIScreen.main.bounds.height / 2)
                Spacer()
            }
            .edgesIgnoringSafeArea(.top)
            VStack {
                VStack {
                    Button(action: {
                        let nfcReaderVC = NFCReaderViewController()
                        nfcReaderVC.delegate = HomeViewNFCDelegate { username, sharedInterests in
                            self.detectedUsername = username
                            self.sharedInterests = sharedInterests
                            self.showConnectionPrompt = true
                        }
                        if let topController = UIApplication.shared.windows.first?.rootViewController {
                            topController.present(nfcReaderVC, animated: true) {
                                nfcReaderVC.startNFCSession(userManager: self.userManager)
                            }
                        }
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Text(username)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    Text(userManager.currentUser?.bio ?? "No bio available")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                }
                Spacer()
                VStack {
                    HStack(spacing: 8) {
                        Spacer()
                        InterestCategoryView(category: "Academic", interests: $interestsManager.interests.academicInterests, color: .orange)
                        InterestCategoryView(category: "Sports", interests: $interestsManager.interests.sportsInterests, color: .orange)
                        InterestCategoryView(category: "Media", interests: $interestsManager.interests.mediaInterests, color: .orange)
                        Spacer()
                    }
                    .padding(.top, 30)
                    HStack {
                        Text("Connections")
                            .font(.headline)
                            .foregroundColor(.gray)
                        GeometryReader { geometry in
                            let segmentWidth = geometry.size.width / 10
                            HStack(spacing: 4) {
                                ForEach(0..<10, id: \.self) { index in
                                    Rectangle()
                                        .fill(index < (userManager.currentUser?.connectionCount ?? 0) ? Color.orange : Color.gray.opacity(0.3))
                                        .frame(width: segmentWidth - 4, height: 20)
                                }
                            }
                        }
                        .frame(height: 20)
                    }
                    .frame(height: 30)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding(.bottom, 20)
                Spacer()
                HStack {
                    Button(action: {
                        isAddingInterest = false
                        showCategorySelection = true
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                            .shadow(radius: 10)
                    }
                    Spacer()
                    Button(action: {
                        showMenu.toggle()
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        isAddingInterest = true
                        showCategorySelection = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .shadow(radius: 10)
                    }
                }
                .padding()
                .sheet(isPresented: $showCategorySelection) {
                    CategorySelectionView(selectedCategory: $selectedCategory, isAdding: $isAddingInterest)
                        .environmentObject(interestsManager)
                }
                .sheet(item: $selectedCategory) { categoryWrapper in
                    EditInterestsView(category: categoryWrapper.category, interests: getInterests(for: categoryWrapper.category))
                        .environmentObject(interestsManager)
                }
                .sheet(isPresented: $showMenu) {
                    MenuView(isSignedIn: $isSignedIn, showConnectionsMap: $showConnectionsMap)
                        .environmentObject(userManager)
                }
                .sheet(isPresented: $showConnectionsMap) {
                    ConnectionsMapView(connections: userManager.currentUser?.connections ?? [])
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
    }
    private func getInterests(for category: String) -> Binding<[String]> {
        switch category {
        case "Academic":
            return $interestsManager.interests.academicInterests
        case "Sports":
            return $interestsManager.interests.sportsInterests
        case "Media":
            return $interestsManager.interests.mediaInterests
        default:
            return .constant([])
        }
    }
}
struct ContentView: View {
    @State private var isSignedIn = false
    @StateObject private var userManager = UserManager()
    @State private var showConnectionPrompt = false
    @State private var detectedUsername = ""
    @State private var sharedInterests: [String] = []
    
    var body: some View {
        NavigationView {
            if isSignedIn {
                if let currentUser = userManager.currentUser {
                    HomeView(isSignedIn: $isSignedIn, username: currentUser.username, showConnectionPrompt: $showConnectionPrompt, detectedUsername: $detectedUsername, sharedInterests: $sharedInterests)
                        .environmentObject(userManager)
                        .environmentObject(userManager.interestsManager)
                        .navigationBarHidden(true)
                }
            } else {
                SignUpLoginView(isSignedIn: $isSignedIn)
                    .environmentObject(userManager)
            }
        }
        .accentColor(.orange)
        .sheet(isPresented: $showConnectionPrompt) {
            ConnectionPromptView(username: detectedUsername, sharedInterests: sharedInterests, onConnect: { photo, location in
                userManager.addConnection(username: detectedUsername, photo: photo, location: location)
                showConnectionPrompt = false
            }, onCancel: {
                showConnectionPrompt = false
            })
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UserManager())
            .environmentObject(InterestsManager())
    }
}
