//  ViewController.swift
//  iOSDeepHole
//
//  Created by Bill Liu on 2019-03-30.
//  Copyright © 2019 Bill Liu. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation
import FirebaseDatabase
import Alamofire
import Foundation

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
    
    func runModel(imageArray: [[[UInt8]]]) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer ya29.GlzdBjS8FLSG4QeZ_qp6Lh1Z9YkolPIrfU1AljoSpjkFNxwWyRRlQ2cj1Zulm5znSk4BGgCZ2nTpGfogEJC_Fc-7PxHiFsh72oy04adJ0cU80cIR8Qfw84CUySSbqA"
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
                let jsonText = json as? String
                print(JSONSerialization.isValidJSONObject(json))
//                do {
//                    let data = try JSONSerialization.data(withJSONObject:jsonText)
//                    let dataString = String(data: data, encoding: .utf8)!
//                    print(dataString)
//
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
            }
        }
    }
    
    struct data: Codable {
        let detection_boxes: Array<Int>
        let detection_classes: Int
        let detection_scores: Float
        let num_detections: Int
    }
    
//    struct Result: Codable {
//        let weather: [Weather]
//    }
//
//    do {
//        let weather = try JSONDecoder().decode(Result.self, from: jsonStr.data(using: .utf8)!)
//        print(weather)
//            }
//        catch {
//        print(error)
//    }
    
    // Convert from NSData to json object
    func nsdataToJSON(data: NSData) -> AnyObject? {
        do {
            return try JSONSerialization.jsonObject(with: data as Data, options: .mutableContainers) as AnyObject
        } catch let myJSONError {
            print(myJSONError)
        }
        return nil
    }
    
    // Convert from JSON to nsdata
    func jsonToNSData(json: AnyObject) -> NSData? {
        do {
            return try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted) as NSData
        } catch let myJSONError {
            print(myJSONError)
        }
        return nil;
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
        runModel(imageArray: image.pixelData()!)
        
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





