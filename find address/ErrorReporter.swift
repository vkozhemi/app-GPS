//
//  ErrorReporter.swift
//  find address
//
//  Created by Andriy GORDIYCHUK on 1/27/19.
//  Copyright © 2019 Volodymyr KOZHEMIAKIN. All rights reserved.
//

import Foundation
import UIKit

final class ErrorReporter {
    class func showError(_ mes:String, from viewController:UIViewController) {
        let alert = UIAlertController(title: "Error", message: mes, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
}
