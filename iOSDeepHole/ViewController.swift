//  ViewController.swift
//  iOSDeepHole
//
//  Created by Bill Liu on 2019-03-30.
//  Copyright © 2019 Bill Liu. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    var imageBuffer = [UIImage()]
    var imagePicker = UIImagePickerController()
    var imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
    var bufferCounter = UILabel()
    var timerOn = UILabel()
    
    var timer : Timer?
    
    var locationBuffer = [CLLocationCoordinate2D()]
    var curLocation : CLLocationCoordinate2D?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        let imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
        imageView.backgroundColor = .blue
        
        bufferCounter.frame = CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 200, width: 160, height: 45)
        bufferCounter.text = "0"
        
        timerOn.frame = CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 300, width: 160, height: 45)
        timerOn.text = "off"
        
        let scanButton = UIButton(frame: CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 100, width: 160, height: 45))
        scanButton.backgroundColor = .blue
        scanButton.setTitle("Take Picture", for: UIControl.State.normal)
        scanButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        
        imagePicker.sourceType = .camera
        imagePicker.delegate =  self
        self.present(imagePicker, animated: true, completion: nil)
        
        self.view.addSubview(scanButton)
        self.view.addSubview(imageView)
        self.view.addSubview(bufferCounter)
        self.view.addSubview(timerOn)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if imageBuffer.endIndex > 5 {
            imageBuffer.remove(at: 0)
        }
        
        if locationBuffer.endIndex > 5 {
            locationBuffer.remove(at: 0)
        }
        
        imageBuffer.append((info[.originalImage] as? UIImage)!)
        imageView.image = imageBuffer.last
        bufferCounter.text = String(imageBuffer.count)
        
        locationBuffer.append(curLocation!)
        
        // process api call to model here
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
            curLocation = location.coordinate
        }
    }

    @objc func buttonAction(sender: UIButton!) {
        print("button tapped")
        imagePicker.takePicture()
        
        if timer != nil {
            timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc func update() {
        print("timer tick")
        
        imagePicker.takePicture()
    }
    
}

extension UIImage {
    func pixelData() -> [UInt8]? {
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
        
        return pixelData
    }
}




