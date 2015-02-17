//
//  ElloButton.swift
//  Ello
//
//  Created by Sean Dougherty on 11/24/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import UIKit

class ElloButton: UIButton {

    override var enabled: Bool {
        didSet {
            self.backgroundColor = enabled ? UIColor.blackColor() : UIColor.grey231F20()
        }
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
        self.sharedSetup()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.sharedSetup()
    }

    func sharedSetup() {
        self.titleLabel?.font = UIFont.typewriterFont(14.0)
        self.titleLabel?.numberOfLines = 1
        self.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        self.setTitleColor(UIColor.greyA(), forState: UIControlState.Disabled)
    }

}

class LightElloButton: ElloButton {
    
    override var enabled: Bool {
        didSet {
            self.backgroundColor = enabled ? UIColor.greyA() : UIColor.greyA()
        }
    }
   
    override func sharedSetup() {
        self.titleLabel?.font = UIFont.typewriterFont(14.0)
        self.titleLabel?.numberOfLines = 1
        self.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        self.setTitleColor(UIColor.blackColor(), forState: UIControlState.Disabled)
    }
    
}
