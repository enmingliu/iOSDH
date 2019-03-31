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

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate, AVCapturePhotoCaptureDelegate {
    
    // photo buffer
    var imageBuffer = [UIImage()]
    
    let locationManager = CLLocationManager()
    var imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
    var bufferCounter = UILabel()
    var timerOn = UILabel()
    
    // var previewView = UIView()
    
    // camera shit
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    // camera shit
    
    var timer = Timer()
    var locationBuffer = [CLLocationCoordinate2D()]
    var curLocation : CLLocationCoordinate2D?
    
    var ref: DatabaseReference!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        ref = Database.database().reference()
        
    }
    
    func runModel(imageArray: [[[UInt8]]], coords: CLLocationCoordinate2D, image: UIImage) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer ya29.GlzdBor4bBAKFcVb-HxymvV4GwX9-9dS9ru3HcTgdwFtO4NslOTk8ZS5Alr8eJ27L-MPWgjmOHEETGPkIWM3lSNVZ6lGq9fjuqdD2PMWFT2HVrCxLq6OEMic93cUeQ"
        ]
        
        let image = [
            "image": imageArray
        ]
        
        let parameters = [
            "instances": image
        ]
        
        Alamofire.request("https://ml.googleapis.com/v1/projects/deephole-fed23/models/detectHole:predict", method: .post, parameters: parameters , encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            print("Request: \(String(describing: response.request))")   // original url request
            print("Response: \(String(describing: response.response))") // http url response
            print("Result: \(response.result)")                         // response serialization result
            
            if let json = response.value {
                print("JSON: \(json)") // serialized json response
                
//
//                print(JSONSerialization.isValidJSONObject(json))
//                do {
//                    let jsonData = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
//
//                    let jsonTry = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
//                    // let dataString = String(data: jsonData, encoding: .utf8)!
//                    print("dataString")
//                    print(JSONSerialization.isValidJSONObject(jsonTry!["predictions"]!))
//
//                    // print(jsonTry!["predictions"]!)
//                    print(json)
//                    print("datab")
//                    print(jsonTry!["predictions"]!)
                
//                    var dict: NSDictionary = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
//
//                    print(dict["predictions"]!)
//
//                    var dict2 : NSDictionary = dict["predictions"]! as! NSDictionary
//                    print("debug")
//                    print(dict2)
//                } catch {
//                    print("JSON serialization failed: ", error)
//                }
//                var dictonary:NSDictionary?
//
//                if let data = jsonText?.data(using: String.Encoding.utf8) {
//
//                    do {
//                        dictonary = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary
//
//                        if let myDictionary = dictonary
//                        {
//                            print(" First name is: \(myDictionary["detection_scores"]!)")
//                        }
//                    } catch let error as NSError {
//                        print(error)
//                    }
//                }
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                print("Data: \(utf8Text)") // original server data as UTF8 string
                let str = utf8Text
                if let index = str.index(of: "detection_scores") {
                    let start = str.index(index, offsetBy: 20)
                    let end = str.index(index, offsetBy: 27)
                    let substring = str[start..<end]   // ab
                    let string = String(substring)
                    print("indexing into")
                    print(string)  // "ab\n"
                    let score = Double(string)
                    print(score!)
                    if (score! >= 0.3) {
                        print("true")
                        let refCoords = self.ref.child("coordinates")
                        let refKey = refCoords.childByAutoId().key
                        
                        let insertJson = [
                            "lat": coords.latitude,
                            "lng": coords.longitude,
                            "media": ""
                            ] as? [String: Any]

                        refCoords.child(refKey!).setValue(insertJson)
                        
                    }
                }
            }
        }
    }
    
    func uploadImage(img: UIImage, id: String){
        let riversRef = Storage.storage().reference(withPath: "images/hole" + id + ".jpg")
        let data = img.pngData()!
        let uploadTask = riversRef.putData(data, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                // Uh-oh, an error occurred!
                return
            }
            metadata.contentType
            // Metadata contains file metadata such as size, content-type.
            let size = metadata.size
            // You can also access to download URL after upload.
        }
        print(riversRef.downloadURL(completion: <#T##(URL?, Error?) -> Void#>))
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("start camera")
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
        
        let imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
        imageView.backgroundColor = .blue
        
        bufferCounter.frame = CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 200, width: 160, height: 45)
        bufferCounter.text = "0"
        imageBuffer.remove(at: 0)
        locationBuffer.remove(at: 0)
        print(imageBuffer.count)
        print(locationBuffer.count)
        
        timerOn.frame = CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 300, width: 160, height: 45)
        timerOn.text = "off"
        
        let scanButton = UIButton(frame: CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 100, width: 160, height: 45))
        scanButton.backgroundColor = .blue
        scanButton.setTitle("Take Picture", for: UIControl.State.normal)
        scanButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        
        self.view.addSubview(scanButton)
        self.view.addSubview(bufferCounter)
        self.view.addSubview(timerOn)
        self.view.addSubview(imageView)
    }
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        self.view.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.view.bounds
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
            curLocation = location.coordinate
        }
    }
    
    @objc func buttonAction(sender: UIButton!) {
        print("button tapped")
        
        if (timer.isValid) {
            timer.invalidate()
            timerOn.text = "off"
        } else {
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
            timerOn.text = "on"
        }
        
        // let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        // stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        if imageBuffer.endIndex >= 5 {
            imageBuffer.remove(at: 0)
        }
        if locationBuffer.endIndex >= 5 {
            locationBuffer.remove(at: 0)
        }
        
        let image = imageWithImage(image: UIImage(data: imageData)!, scaledToSize: CGSize(width: 100, height: 100))
        print(image.size)
        imageView.backgroundColor = .clear
        // imageView.image = image
        imageBuffer.append(image)
        locationBuffer.append(curLocation!)
        print("location count")
        print(locationBuffer.count)
        // first
        imageView.image = imageBuffer.first
        bufferCounter.text = String(imageBuffer.count)
        self.view.addSubview(imageView)
        print("photoOutput")
        runModel(imageArray: imageBuffer.first!.pixelData()!, coords: locationBuffer.first!, image: imageBuffer.first!)
//
//
//
//        if isPotHole {
//            print("SENT!")
//            let refCoords = self.ref.child("coordinates")
//            let refKey = refCoords.childByAutoId().key
//
//            let insertJson = [
//                "lat": locationBuffer.first?.latitude,
//                "lng": locationBuffer.first?.longitude,
//                "media": ""
//                ] as? [String: Any]
//
//            refCoords.child(refKey!).setValue(insertJson)
//        }
    }
    
    
    @objc func update() {
        print("timer tick")
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    func imageWithImage(image:UIImage, scaledToSize newSize:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        image.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
}

extension UIImage {
    func pixelData() -> [[[UInt8]]]? {
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
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



