//
//  ViewController.swift
//  Image Finder
//
//  Created by Steven Hurtado on 12/29/16.
//  Copyright © 2016 Steven Hurtado. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{

    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var finderTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    //label layers for intro animation
    @IBOutlet weak var layer1: UILabel!
    @IBOutlet weak var layer2: UILabel!
    @IBOutlet weak var layer3: UILabel!

    @IBOutlet weak var layer4: UILabel!
    
    // MARK: Life Cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        beginningAnimation()
        self.photoImageView.alpha = 0
        
        self.photoImageView.contentMode = .scaleAspectFit
        
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject)
    {
        userDidTapView(self)
        setUIEnabled(false)
        
        
        if !phraseTextField.text!.isEmpty
        {
            self.exitingAnimation()
            
            //animate alpha of image; fade out
            UIView.animate(withDuration: 0.4, animations:
            {
                    self.photoImageView.alpha = 0
            })
            
            finderTitleLabel.text = "Searching..."
            
            let methodParameters : [String : String?] =
                [
                    Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                    Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                    Constants.FlickrParameterKeys.Text:
                        phraseTextField.text!,
                    Constants.FlickrParameterKeys.SafeSearch:
                        Constants.FlickrParameterValues.UseSafeSearch,
                    Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                    Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                    Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]

            
            displayImageFromFlickrBySearch(methodParameters as [String : AnyObject])
        }
        else
        {
            setUIEnabled(true)
            finderTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject)
    {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange)
        {
            finderTitleLabel.text = "Searching..."
        
            self.exitingAnimation()
            
            //animate alpha of image; fade out
            UIView.animate(withDuration: 0.4, animations:
            {
                    self.photoImageView.alpha = 0
            })

            
            let methodParameters : [String : String?] =
                [
                    Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                    Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                    Constants.FlickrParameterKeys.Text:
                        phraseTextField.text!,
                    Constants.FlickrParameterKeys.SafeSearch:
                        Constants.FlickrParameterValues.UseSafeSearch,
                    Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                    Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                    Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            
            
            displayImageFromFlickrBySearch(methodParameters as [String : AnyObject])
        }
        else
        {
            setUIEnabled(true)
            finderTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String
    {
        if let latitude = Double(latitudeTextField.text!), let longitude = Double(longitudeTextField.text!)
        {
            let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        }
        else
        {
            return "0,0,0,0"
        }
        
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject])
    {
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = URLSession.shared.dataTask(with: request)
        {
            (data, response, error) in
            
            func displayError(_ error: String)
            {
                print(error)
                performUIUpdatesOnMain
                    {
                        self.setUIEnabled(true)
                }
            }
            
            
            /* GUARD: Was there an error? */
            guard (error == nil)
                else
            {
                displayError("There was an error with your request: \(error)")

                //check if error is from no internet connection
                if let error = error as? NSError, error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet
                {
                    self.finderTitleLabel.text = "Error: Connection offline!"
                }
                else
                {
                    self.finderTitleLabel.text = "Error: Unknown Error"
                }
                
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299
                else
            {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data
                else
            {
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do
            {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            }
            catch
            {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus
                else
            {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult!)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]]
                else
            {
                displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                return
            }
            
            // select a random photo
            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
            let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]
            let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
            
            /* GUARD: Does our photo have a key for 'url_m'? */
            guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String
                else
            {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                return
            }
            
            // if an image exists at the url, set the image and title
            let imageURL = URL(string: imageUrlString)
            if let imageData = try? Data(contentsOf: imageURL!)
            {
                performUIUpdatesOnMain
                    {
                        self.setUIEnabled(true)
                        
                        self.photoImageView.image = UIImage(data: imageData)
                        
                        //animate alpha of image; fade in
                        UIView.animate(withDuration: 0.4, animations:
                            {
                                self.photoImageView.alpha = 1
                        })
                        
                        self.beginningAnimation()
                        
                        self.layer1.text = photoTitle ?? "(Untitled)"
                        self.layer2.text = "URL: \(imageURL!)"
                        self.layer3.text = "HTTP Status Code: \(statusCode)"
                        
                        self.finderTitleLabel.text = "Photo found!"
                }
            }
            else
            {
                displayError("Image does not exist at \(imageURL)")
                self.finderTitleLabel.text = "Photo not found..."
            }
        }
        
        task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL
    {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters
        {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        print(components.url!)
        
        return components.url!
    }
    
    
    func beginningAnimation()
    {
        UIView.animate(withDuration: 0.0001, animations:
            {
                self.layer1.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer2.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer3.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer4.transform = CGAffineTransform(translationX: 0, y: 156)
        })
        
        UIView.animate(withDuration: 0.5, animations:
            {
                self.layer1.transform = CGAffineTransform(translationX: 0, y: -40)
                
                self.layer2.transform = CGAffineTransform(translationX: 0, y: -40)
                
                self.layer3.transform = CGAffineTransform(translationX: 0, y: -40)
                
                self.layer4.transform = CGAffineTransform(translationX: 0, y: -40)
        })
        
        UIView.animate(withDuration: 1, animations:
            {
                self.layer1.transform = CGAffineTransform(translationX: 0, y: 4)
                
                self.layer2.transform = CGAffineTransform(translationX: 0, y: 4)
                
                self.layer3.transform = CGAffineTransform(translationX: 0, y: 4)
                
                self.layer4.transform = CGAffineTransform(translationX: 0, y: 4)
        })
        
    }
    
    func exitingAnimation()
    {
        UIView.animate(withDuration: 0.5, animations:
        {
                self.layer1.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer2.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer3.transform = CGAffineTransform(translationX: 0, y: 156)
                
                self.layer4.transform = CGAffineTransform(translationX: 0, y: 156)
        })
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate
{
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification)
    {
        if !keyboardOnScreen
        {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification)
    {
        if keyboardOnScreen
        {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification)
    {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification)
    {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat
    {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField)
    {
        if textField.isFirstResponder
        {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject)
    {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool
    {
        if let value = Double(textField.text!), !textField.text!.isEmpty
        {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        }
        else
        {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool
    {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController
{
    
    func setUIEnabled(_ enabled: Bool)
    {
//        photoTitleLabel.isEnabled = enabled
        finderTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled
        {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        }
        else
        {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController
{
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector)
    {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications()
    {
        NotificationCenter.default.removeObserver(self)
    }
}
