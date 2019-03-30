//
//  ViewController.swift
//  iOSDeepHole
//
//  Created by Bill Liu on 2019-03-30.
//  Copyright © 2019 Bill Liu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let imageView = UIImageView(frame: CGRect(x: 125, y: 150, width: 200, height: 200))
        imageView.backgroundColor = .blue
        
        let scanButton = UIButton(frame: CGRect(x: self.view.frame.width / 2, y: self.view.frame.height - 100, width: 160, height: 45))
        scanButton.backgroundColor = .blue
        scanButton.setTitle("Take Picture", for: UIControl.State.normal)
        scanButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate =  self
        self.present(imagePicker, animated: true, completion: nil)
        
        self.view.addSubview(scanButton)
        self.view.addSubview(imageView)
    }

    @objc func buttonAction(sender: UIButton!) {
        print("button tapped")
        
    }
    
}

