//
//  ViewController.swift
//  iOSDeepHole
//
//  Created by Bill Liu on 2019-03-30.
//  Copyright © 2019 Bill Liu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var imageBuffer = [UIImage()]
    var imagePicker = UIImagePickerController()
    var imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
    var bufferCounter = UILabel()
    var timerOn = UILabel()
    
    var timer : Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        imageBuffer.append((info[.originalImage] as? UIImage)!)
        imageView.image = imageBuffer.last
        bufferCounter.text = String(imageBuffer.count)
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
    }
    
}

