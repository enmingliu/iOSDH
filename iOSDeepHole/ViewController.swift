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
        
        let image = UIImage(data: imageData)
        imageView.backgroundColor = .clear
        // imageView.image = image
        imageBuffer.append(image!)
        locationBuffer.append(curLocation!)
        print("location count")
        print(locationBuffer.count)
        // first
        imageView.image = imageBuffer.first
        bufferCounter.text = String(imageBuffer.count)
        self.view.addSubview(imageView)
        print("photoOutput")
        let rgba = RGBAImage(image: image!)!
        print(rgba.pixels)
        print(image?.pixelData())
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
    
}

public struct Pixel {
    
    //각 색상 컴포넌트는 ABGR 순으로 저장되어 있다.
    public var value: UInt32
    
    //red
    public var R: UInt8 {
        get { return UInt8(value & 0xFF); }
        set { value = UInt32(newValue) | (value & 0xFFFFFF00) }
    }
    
    //green
    public var G: UInt8 {
        get { return UInt8((value >> 8) & 0xFF) }
        set { value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF) }
    }
    
    //blue
    public var B: UInt8 {
        get { return UInt8((value >> 16) & 0xFF) }
        set { value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF) }
    }
    
    //alpha
    public var A: UInt8 {
        get { return UInt8((value >> 24) & 0xFF) }
        set { value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF) }
    }
}

public struct RGBAImage {
    public var pixels: UnsafeMutableBufferPointer<Pixel>
    public var width: Int
    public var height: Int
    
    public init?(image: UIImage) {
        // CGImage로 변환이 가능해야 한다.
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        // 주소 계산을 위해서 Float을 Int로 저장한다.
        width = Int(image.size.width)
        height = Int(image.size.height)
        
        // 4 * width * height 크기의 버퍼를 생성한다.
        let bytesPerRow = width * 4
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        
        // 색상공간은 Device의 것을 따른다
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // BGRA로 비트맵을 만든다
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo = bitmapInfo | CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        // 비트맵 생성
        guard let imageContext = CGContext(data: imageData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        // cgImage를 imageData에 채운다.
        imageContext.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        
        pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
    }
    
    public func toUIImage() -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        let bytesPerRow = width * 4
        
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        guard let imageContext = CGContext(data: pixels.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, releaseCallback: nil, releaseInfo: nil) else {
            return nil
        }
        
        guard let cgImage = imageContext.makeImage() else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        return image
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






