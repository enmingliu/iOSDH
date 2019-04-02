//  ViewController.swift
//  iOSDeepHole
//
//  Created by Bill Liu on 2019-03-30.
//  Copyright © 2019 Bill Liu. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation
import Firebase
import FirebaseDatabase
import Alamofire
import Foundation
import FirebaseStorage
import Speech

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate, AVCapturePhotoCaptureDelegate, SFSpeechRecognizerDelegate {
    
    var imageBuffer = [UIImage()] // photo buffer
    
    var imageView = UIImageView(frame: CGRect(x: 0, y: 483, width: 100, height: 100))
    
    var timer = Timer()
    
    // capture session
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    // location data
    let locationManager = CLLocationManager()
    var locationBuffer = [CLLocationCoordinate2D()] // location buffer
    var curLocation : CLLocationCoordinate2D?       // current location data
    
    var ref: DatabaseReference!
    
    // ML model response icons
    var check = UIImageView()
    var cancel = UIImageView()
    
    // audio
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(red: 186/255, green: 226/255, blue: 244/255, alpha: 1)
        UIApplication.shared.isIdleTimerDisabled = true
        
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        ref = Database.database().reference()
        
        // camera toggle button
        let button = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 184/2, width: self.view.frame.width/2, height: 184 / 2))
        button.setTitle("Camera", for: .normal)
        button.addTarget(self, action: #selector(toggleCamera), for: .touchUpInside)
        button.backgroundColor = UIColor(red: 65/255, green: 127/255, blue: 226/255, alpha: 0.7)
        let cam: UIImage = UIImage(named: "camera.png")!
        button.setImage(cam, for: UIControl.State.normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 25, left: 72, bottom: 25, right: 72)
        self.view.addSubview(button)
        
        // toggle voice command button
        let button1 = UIButton(frame: CGRect(x: self.view.frame.width/2, y: self.view.frame.height - 184/2, width: self.view.frame.width/2, height: 184 / 2))
        button1.setTitle("Mic", for: .normal)
        button1.addTarget(self, action: #selector(toggleMic), for: .touchUpInside)
        button1.backgroundColor = UIColor(red: 81/255, green: 183/255, blue: 247/255, alpha: 0.7)
        let mic: UIImage = UIImage(named: "microphone-for-singers.png")!
        button1.setImage(mic, for: UIControl.State.normal)
        button1.imageEdgeInsets = UIEdgeInsets(top: 25, left: 72, bottom: 25,right: 72)
        self.view.addSubview(button1)
        
        // app logo
        let logo = UIImageView(frame: CGRect(x: self.view.frame.width / 2 - 25, y: 25, width: 50, height: 50))
        logo.image = imageWithImage(image: UIImage(named: "icon.png")!, scaledToSize: CGSize(width: 184/2, height: 184/2))
        self.view.addSubview(logo)
    }

    // on toggle camera button press
    @objc func toggleCamera(sender: UIButton!) {
        if sender.backgroundColor == UIColor(red: 65/255, green: 127/255, blue: 226/255, alpha: 0.7) {
            sender.backgroundColor = UIColor(red: 65/255, green: 127/255, blue: 226/255, alpha: 1.0)
        } else {
            sender.backgroundColor = UIColor(red: 65/255, green: 127/255, blue: 226/255, alpha: 0.7)
        }
        
        // turn timer on/off
        if (timer.isValid) {
            timer.invalidate()
        } else {
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
        }
    }
    
    // on toggle microphone button press
    @objc func toggleMic(sender: UIButton!) {
        // begin/stop recording audio
        if sender.backgroundColor == UIColor(red: 81/255, green: 183/255, blue: 247/255, alpha: 0.7) {
            sender.backgroundColor = UIColor(red: 81/255, green: 183/255, blue: 247/255, alpha: 1.0)
            self.recordAndRecognizeSpeech()
        } else {
            sender.backgroundColor = UIColor(red: 81/255, green: 183/255, blue: 247/255, alpha: 0.7)
            recognitionTask?.finish()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    // called when starting to record audio
    func recordAndRecognizeSpeech() {
        // setup audio engine and speech recognizer
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
        guard let myRecognizer = SFSpeechRecognizer() else {
            return
        }
        if !myRecognizer.isAvailable {
            return
        }
        
        // closure that operates on recognized speech data
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
            if let result = result {
                let bestString = result.bestTranscription.formattedString   // string transcription of best recognized result
                
                // getting last spoken word from result
                var lastString: String = ""
                for segment in result.bestTranscription.segments {
                    let indexTo = bestString.index(bestString.startIndex, offsetBy: segment.substringRange.location)
                    lastString = bestString.substring(from: indexTo)
                }
                
                if lastString == "report" { // "report" is voice activated command
                    self.locationBuffer.append(self.curLocation!)   // append location to buffer
       
                    // write report to firebase realtime database
                    let refCoords = self.ref.child("coordinates")
                    let refKey = refCoords.childByAutoId().key
                    let insertJson = [
                        "date": "31-03-2019",
                        "email": "enmingliu@g.ucla.edu",
                        "imgURL": "",
                        "manual": "YES",
                        "phone": "(310) 666-0225",
                        "time": "10:59 pm",
                        "lat": self.locationBuffer.first!.latitude,
                        "lng": self.locationBuffer.first!.longitude,
                        ] as? [String: Any]
                    refCoords.child(refKey!).setValue(insertJson)

                    // animate ML model response icons
                    UIView.animate(withDuration: 0.4, animations: {
                        self.check.alpha = 1
                    })
                    UIView.animate(withDuration: 1, animations: {
                        self.check.alpha = 0
                    })
                }
            } else if let error = error {
                print(error)
            }
        })
    }
    
    // makes post request to ML model hosted on GCP ML Enginer
    func runModel(imageArray: [[[UInt8]]], coords: CLLocationCoordinate2D, im: UIImage) {
        let headers: HTTPHeaders = [    // authorization token
            "Authorization": "Bearer ya29.GlzdBo2fl1ztZXvAXRNfrgbS4ZN7wVTZOQsmORXcnseyUSFC574ISf7M3i8g3PXeQz24O2pT_DWu1oUxU5qu15-561oT90CWQGBvh_-_tmuwx8OX6jj0mehknNH2MQ"
        ]
        let image = [
            "image": imageArray
        ]
        let parameters = [
            "instances": image
        ]
        
        // closure to handle ML model response
        Alamofire.request("https://ml.googleapis.com/v1/projects/deephole-fed23/models/detectHole:predict", method: .post, parameters: parameters , encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            print("Request: \(String(describing: response.request))")   // original url request
            print("Response: \(String(describing: response.response))") // http url response
            print("Result: \(response.result)")                         // response serialization result
            
            if let json = response.value {
                print("JSON: \(json)") // serialized json response
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                print("Data: \(utf8Text)") // original server data as UTF8 string
                let str = utf8Text
                if let index = str.index(of: "detection_scores") {  // parsing through response JSON
                    let start = str.index(index, offsetBy: 20)
                    let end = str.index(index, offsetBy: 27)
                    let substring = str[start..<end]
                    let string = String(substring)
                    let score = Double(string)
                    if (score! >= 0.3) {    // if classification score is >= 0.3, proceed with report
                        // animate ML model response icons
                        UIView.animate(withDuration: 0.4, animations: {
                            self.check.alpha = 1
                        })
                        UIView.animate(withDuration: 0.4, animations: {
                            self.check.alpha = 0
                        })
                        
                        // write report to database
                        let refCoords = self.ref.child("coordinates")
                        let refKey = refCoords.childByAutoId().key
                        let insertJson = [
                            "date": "31-03-2019",
                            "email": "enmingliu@g.ucla.edu",
                            "imgURL": "",
                            "manual": "NO",
                            "phone": "(310) 666-0225",
                            "time": "10:59 pm",
                            "lat": coords.latitude,
                            "lng": coords.longitude,
                            ] as? [String: Any]
                        refCoords.child(refKey!).setValue(insertJson)
                        
                        // upload image to firebase cloud storage
                        self.uploadImage(img: im, id: refKey!)
                    } else {
                        UIView.animate(withDuration: 0.4, animations: {
                            self.cancel.alpha = 1
                        })
                        UIView.animate(withDuration: 0.4, animations: {
                            self.cancel.alpha = 0
                        })
                    }
                }
            }
        }
    }
    
    // called upon upload of pothole image to firebase cloud storage
    func uploadImage(img: UIImage, id: String) {
        let riversRef = Storage.storage().reference(withPath: "images/hole" + id + ".jpg")  // set up reference to realtime database
        let data = img.pngData()!
        let uploadTask = riversRef.putData(data, metadata: nil) { (metadata, error) in  // closure to process media upload metadata
            guard let metadata = metadata else {
                return
            }
            // writing cloud storage media url to realtime database after upload
            riversRef.downloadURL { (url, error) in
                if let error = error {
                    print("errored")
                    print(error)
                } else {
                    let refCoords = self.ref.child("coordinates")
                    print("yes")
                    print(url?.absoluteString)
                    refCoords.child(id).child("imgURL").setValue(url?.absoluteString)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // start capture session
        timer.invalidate()
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                return
        }
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
        
        // initialize image preview
        let imageView = UIImageView(frame: CGRect(x: 0, y: self.view.frame.height - 184, width: 100, height: 100))
        imageView.backgroundColor = .clear
        self.view.addSubview(imageView)
        
        // clear buffers
        imageBuffer.remove(at: 0)
        locationBuffer.remove(at: 0)
        print(imageBuffer.count)
        print(locationBuffer.count)
        
        // ML model response icons
        check = UIImageView(frame: CGRect(x: self.view.frame.width - 40, y: 184/2, width: 40, height: 40))
        check.image = imageWithImage(image: UIImage(named: "checked.png")!, scaledToSize: CGSize(width: 184/2, height: 184/2))
        check.alpha = 0
        self.view.addSubview(check)
        cancel = UIImageView(frame: CGRect(x: self.view.frame.width - 40, y: 184/2, width: 40, height: 40))
        cancel.image = imageWithImage(image: UIImage(named: "cancel.png")!, scaledToSize: CGSize(width: 184/2, height: 184/2))
        cancel.alpha = 0
        self.view.addSubview(cancel)
    }
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        self.view.layer.addSublayer(videoPreviewLayer)

        DispatchQueue.global(qos: .userInitiated).async { // dispatch queue async call to initialize video frame bounds
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.view.bounds
            }
        }
    }
    
    // updates current coordinate location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
            curLocation = location.coordinate
        }
    }
    
    // called whenever a photo is taken
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        // handle buffer overflow
        if imageBuffer.endIndex >= 5 {
            imageBuffer.remove(at: 0)
        }
        if locationBuffer.endIndex >= 5 {
            locationBuffer.remove(at: 0)
        }
        
        // initialize preview image view
        let image = imageWithImage(image: UIImage(data: imageData)!, scaledToSize: CGSize(width: 100, height: 100))
        imageView.backgroundColor = .clear
        imageBuffer.append(image)
        imageView.image = imageBuffer.first
        self.view.addSubview(imageView)
        
        // update location buffer
        locationBuffer.append(curLocation!)
        
        // call ML model
        runModel(imageArray: imageBuffer.first!.pixelData()!, coords: locationBuffer.first!, im: imageBuffer.first!)
    }
    
    // called every timer tick
    @objc func update() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    // rescales any uiimage to any CGSize
    func imageWithImage(image:UIImage, scaledToSize newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        image.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension UIImage {
    // converts an UIImage to its pixel rgb data in the form of a 3D-array
    func pixelData() -> [[[UInt8]]]? {
        // transforms UIImage to pixel rgba data in form of a 1D-array
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        // converts 1D rgba pixel data to 3D rgb pixel data (alpha unnecessary)
        var finalPixelData = [[[UInt8]]](repeating: [[UInt8]](repeating: [], count: Int(size.height)), count: Int(size.width))
        var count = 0
        for w in 0 ..< Int(size.width) {
            for h in 0 ..< Int(size.height) {
                for rgbaVal in 0 ..< 4 {
                    if rgbaVal != 3 {
                        finalPixelData[w][h].append(pixelData[count])
                    }
                    count += 1
                }
            }
        }
        
        return finalPixelData
    }
}

extension StringProtocol where Index == String.Index {
    // suite of extended functions for strings to return the index of a substring in a string 
    func index(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    func endIndex(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    func indexes(of string: Self, options: String.CompareOptions = []) -> [Index] {
        var result: [Index] = []
        var start = startIndex
        while start < endIndex,
            let range = self[start..<endIndex].range(of: string, options: options) {
                result.append(range.lowerBound)
                start = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    func ranges(of string: Self, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var start = startIndex
        while start < endIndex,
            let range = self[start..<endIndex].range(of: string, options: options) {
                result.append(range)
                start = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
