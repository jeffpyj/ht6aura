//
//  ViewController.swift
//  Created by Jeff Peng on 2018-08-25.
//  Copyright © 2018 Jeff Peng. All rights reserved.
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

import UIKit
import Foundation
import TwilioVideo

class ViewController: UIViewController {

    // MARK: View Controller Members
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
    var accessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzU2NTViZjQwNzJhNjJjMjU4YzczMjM2MDU3ZDA1MTU0LTE1MzUyNjI5NTkiLCJpc3MiOiJTSzU2NTViZjQwNzJhNjJjMjU4YzczMjM2MDU3ZDA1MTU0Iiwic3ViIjoiQUNiN2IxYWUyZmExNTc3M2M2NGUyZjIzNTkyODk4NWU0NSIsImV4cCI6MTUzNTI2NjU1OSwiZ3JhbnRzIjp7ImlkZW50aXR5IjoidGVzdDIiLCJ2aWRlbyI6e319fQ.dMWEvJVZ0OIAjE0fTxceL45rGDbgoXozv0jpeeZdUgs"
  
    // Configure remote URL to fetch token from
    var tokenUrl = "http://localhost:8000/token.php"
    
    // Video SDK components
    var room: TVIRoom?
    var camera: TVICameraCapturer?
    var localVideoTrack: TVILocalVideoTrack?
    var localAudioTrack: TVILocalAudioTrack?
    var remoteParticipant: TVIRemoteParticipant?
    var remoteView: TVIVideoView?
    
    // MARK: UI Element Outlets and handles
    
    // `TVIVideoView` created from a storyboard
    @IBOutlet weak var previewView: TVIVideoView!

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var roomTextField: UITextField!
    @IBOutlet weak var roomLine: UIView!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!

    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var downButton: UIButton!
    
    @IBOutlet weak var pleftButton: UIButton!
    @IBOutlet weak var tupButton: UIButton!
    @IBOutlet weak var tdownButton: UIButton!
    @IBOutlet weak var prightButton: UIButton!
    
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var viewButton: UIButton!
    
    @IBOutlet weak var modeButton: UIButton!
    
    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "aura"
        self.messageLabel.adjustsFontSizeToFitWidth = true;
        self.messageLabel.minimumScaleFactor = 0.75;

        if PlatformUtils.isSimulator {
            self.previewView.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        // Disconnect and mic button will be displayed when the Client is connected to a Room.
        self.disconnectButton.isHidden = true
        self.micButton.isHidden = true
        self.upButton.isHidden = true
        self.leftButton.isHidden = true
        self.downButton.isHidden = true
        self.rightButton.isHidden = true
        self.tupButton.isHidden = true
        self.pleftButton.isHidden = true
        self.tdownButton.isHidden = true
        self.prightButton.isHidden = true
        
        self.moveButton.isHidden = true
        self.viewButton.isHidden = true
        
        self.modeButton.isHidden = true
        
        self.roomTextField.autocapitalizationType = .none
        self.roomTextField.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }
    
    func setupRemoteVideoView() {
        // Creating `TVIVideoView` programmatically
        self.remoteView = TVIVideoView.init(frame: CGRect.zero, delegate:self)
        
        self.view.insertSubview(self.remoteView!, at: 0)
        
        // `TVIVideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;

        let centerX = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: .centerX,
                                         relatedBy: .equal,
                                         toItem: self.view,
                                         attribute: .centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: self.view,
                                         attribute: .centerY,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: self.remoteView!,
                                       attribute: .width,
                                       relatedBy: .equal,
                                       toItem: self.view,
                                       attribute: .width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: self.remoteView!,
                                        attribute: .height,
                                        relatedBy: .equal,
                                        toItem: self.view,
                                        attribute: .height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
    }

    // MARK: IBActions
    @IBAction func connect(sender: AnyObject) {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            do {
                accessToken = try TokenUtils.fetchToken(url: tokenUrl)
            } catch {
                let message = "Failed to fetch access token"
                logMessage(messageText: message)
                return
            }
        }
        
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = TVIConnectOptions.init(token: accessToken) { (builder) in
            
            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [TVILocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [TVILocalVideoTrack]()
            
            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec]
            }
            
            // Use the preferred video codec
            if let preferredVideoCodec = Settings.shared.videoCodec {
                builder.preferredVideoCodecs = [preferredVideoCodec]
            }
            
            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = self.roomTextField.text
        }
        
        // Connect to the Room using the options we provided.
        room = TwilioVideo.connect(with: connectOptions, delegate: self)
        
        logMessage(messageText: "Attempting to connect to room \(String(describing: self.roomTextField.text))")
        
        self.showRoomUI(inRoom: true)
        self.dismissKeyboard()
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        self.room!.disconnect()
        logMessage(messageText: "Attempting to disconnect from room \(room!.name)")
    }
    
    @IBAction func toggleMic(sender: AnyObject) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            
            // Update the button title
            if (self.localAudioTrack?.isEnabled == true) {
                self.micButton.setImage(UIImage(named: "Mute.png"), for: [])
            } else {
                self.micButton.setImage(UIImage(named: "Unmute.png"), for: [])
                //self.micButton.setTitle("Unmute", for: .normal)
            }
        }
    }
    
    @IBAction func UpPress(_ sender: UIButton) {
        sendActionRequest(input: "w")
    }
    @IBAction func UpRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func LeftPress(_ sender: UIButton) {
        sendActionRequest(input: "a")
    }
    
  
    @IBAction func LeftRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func RightPress(_ sender: UIButton) {
        sendActionRequest(input: "d")
    }
    
    @IBAction func RightRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func DownPress(_ sender: UIButton) {
        sendActionRequest(input: "s")
    }
    
    @IBAction func DownRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func TUpPress(_ sender: UIButton) {
        sendActionRequest(input: "i")
    }
    
    @IBAction func TUpDown(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func PLeftPress(_ sender: UIButton) {
        sendActionRequest(input: "j")
    }
    
    @IBAction func PLeftRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func TDownPress(_ sender: UIButton) {
        sendActionRequest(input: "k")
    }
    
    @IBAction func TDownRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
    
    @IBAction func PRightPress(_ sender: UIButton) {
        sendActionRequest(input: "l")
    }
    
    @IBAction func PRightRelease(_ sender: UIButton) {
        sendActionRequest(input: "x")
    }
  
    
    @IBAction func changeMode(_ sender: UIButton) {
        self.previewView.isHidden = !self.previewView.isHidden
        self.upButton.isHidden = !self.upButton.isHidden
        self.leftButton.isHidden = !self.leftButton.isHidden
        self.downButton.isHidden = !self.downButton.isHidden
        self.rightButton.isHidden = !self.rightButton.isHidden
        
        self.tupButton.isHidden = !self.tupButton.isHidden
        self.pleftButton.isHidden = !self.pleftButton.isHidden
        self.tdownButton.isHidden = !self.tdownButton.isHidden
        self.prightButton.isHidden = !self.prightButton.isHidden
        
        self.moveButton.isHidden = !self.moveButton.isHidden
        self.viewButton.isHidden = !self.viewButton.isHidden
    }
    
    func sendActionRequest(input: String) {
        // Set up the URL request
        let todoEndpoint: String = "http://hack-the-six.mybluemix.net/control?payload=\(input)&topic="
        guard let url = URL(string: todoEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        let urlRequest = URLRequest(url: url)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        // make the request
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error calling GET on /todos/1")
                print(error!)
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                guard let todo = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        print("error trying to convert data to JSON")
                        return
                }
                // now we have the todo
                // let's just print it to prove we can access it
                print("The todo is: " + todo.description)
                
                // the todo object is a dictionary
                // so we just access the title using the "title" key
                // so check for a title and print it if we have one
                guard let todoTitle = todo["title"] as? String else {
                    print("Could not get todo title from JSON")
                    return
                }
                print("The title is: " + todoTitle)
            } catch  {
                print("error trying to convert data to JSON")
                return
            }
        }
        task.resume()
    }
    // MARK: Private
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        // Preview our local camera track in the local video preview view.
        camera = TVICameraCapturer(source: .frontCamera, delegate: self)
        localVideoTrack = TVILocalVideoTrack.init(capturer: camera!, enabled: true, constraints: nil, name: "Camera")
        if (localVideoTrack == nil) {
            logMessage(messageText: "Failed to create video track")
        } else {
            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.previewView)

            logMessage(messageText: "Video track created")

            // We will flip camera on tap.
            let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.flipCamera))
            self.previewView.addGestureRecognizer(tap)
        }
    }

    @objc func flipCamera() {
        if (self.camera?.source == .frontCamera) {
            self.camera?.selectSource(.backCameraWide)
        } else {
            self.camera?.selectSource(.frontCamera)
        }
    }

    func prepareLocalMedia() {

        // We will share local audio and video when we connect to the Room.

        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = TVILocalAudioTrack.init(options: nil, enabled: true, name: "Microphone")

            if (localAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }

        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
   }

    // Update our UI based upon if we are in a Room or not
    func showRoomUI(inRoom: Bool) {
        self.connectButton.isHidden = inRoom
        self.roomTextField.isHidden = inRoom
        self.roomLine.isHidden = inRoom
        self.roomLabel.isHidden = inRoom
        self.micButton.isHidden = !inRoom
        self.disconnectButton.isHidden = !inRoom
        
        self.upButton.isHidden = !inRoom
        self.leftButton.isHidden = !inRoom
        self.downButton.isHidden = !inRoom
        self.rightButton.isHidden = !inRoom
        
        self.tupButton.isHidden = !inRoom
        self.pleftButton.isHidden = !inRoom
        self.tdownButton.isHidden = !inRoom
        self.prightButton.isHidden = !inRoom
        
        self.moveButton.isHidden = !inRoom
        self.viewButton.isHidden = !inRoom
        
        self.modeButton.isHidden = !inRoom
        
        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
        UIApplication.shared.isIdleTimerDisabled = inRoom
    }
    
    @objc func dismissKeyboard() {
        if (self.roomTextField.isFirstResponder) {
            self.roomTextField.resignFirstResponder()
        }
    }
    
    func cleanupRemoteParticipant() {
        if ((self.remoteParticipant) != nil) {
            if ((self.remoteParticipant?.videoTracks.count)! > 0) {
                let remoteVideoTrack = self.remoteParticipant?.remoteVideoTracks[0].remoteTrack
                remoteVideoTrack?.removeRenderer(self.remoteView!)
                self.remoteView?.removeFromSuperview()
                self.remoteView = nil
            }
        }
        self.remoteParticipant = nil
    }
    
    func logMessage(messageText: String) {
        messageLabel.text = messageText
    }
}

// MARK: UITextFieldDelegate
extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.connect(sender: textField)
        return true
    }
}

// MARK: TVIRoomDelegate
extension ViewController : TVIRoomDelegate {
    func didConnect(to room: TVIRoom) {
        
        // At the moment, this example only supports rendering one Participant at a time.
        
        logMessage(messageText: "Connected to room \(room.name) as \(String(describing: room.localParticipant?.identity))")
        
        if (room.remoteParticipants.count > 0) {
            self.remoteParticipant = room.remoteParticipants[0]
            self.remoteParticipant?.delegate = self
        }
    }
    
    func room(_ room: TVIRoom, didDisconnectWithError error: Error?) {
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, didFailToConnectWithError error: Error) {
        logMessage(messageText: "Failed to connect to room with error")
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, participantDidConnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == nil) {
            self.remoteParticipant = participant
            self.remoteParticipant?.delegate = self
        }
       logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }
    
    func room(_ room: TVIRoom, participantDidDisconnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == participant) {
            cleanupRemoteParticipant()
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
    }
}

// MARK: TVIRemoteParticipantDelegate
extension ViewController : TVIRemoteParticipantDelegate {
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has offered to share the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has stopped sharing the video Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has offered to share the audio Track.

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has stopped sharing the audio Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

   func subscribed(to videoTrack: TVIRemoteVideoTrack,
                    publication: TVIRemoteVideoTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's video frames now.
        
        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            setupRemoteVideoView()
            videoTrack.addRenderer(self.remoteView!)
        }
    }
    
    func unsubscribed(from videoTrack: TVIRemoteVideoTrack,
                      publication: TVIRemoteVideoTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            videoTrack.removeRenderer(self.remoteView!)
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
        }
    }
    
    func subscribed(to audioTrack: TVIRemoteAudioTrack,
                    publication: TVIRemoteAudioTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
       
        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func unsubscribed(from audioTrack: TVIRemoteAudioTrack,
                      publication: TVIRemoteAudioTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
   func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func failedToSubscribe(toAudioTrack publication: TVIRemoteAudioTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func failedToSubscribe(toVideoTrack publication: TVIRemoteVideoTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK: TVIVideoViewDelegate
extension ViewController : TVIVideoViewDelegate {
    func videoView(_ view: TVIVideoView, videoDimensionsDidChange dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: TVICameraCapturerDelegate
extension ViewController : TVICameraCapturerDelegate {
    func cameraCapturer(_ capturer: TVICameraCapturer, didStartWith source: TVICameraCaptureSource) {
        self.previewView.shouldMirror = (source == .frontCamera)
    }
}
