//
//  Constants.swift
//  Photo-pin
//
//  Created by Nikita Popov on 15.02.2021.
//

import Foundation

let apiKey = "1a6031021d48a863289a2ef254e805af"


func flickrUrl(forApiKey apiKey: String, withAnnotation anotation: DroppablePin, andNumberOfPhotos number: Int) -> String{
    
    let url = "https://www.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&lat=\(anotation.coordinate.latitude)&lon=\(anotation.coordinate.longitude)&radius=1&radius_units=km&per_page=\(number)&format=json&nojsoncallback=1"
    
    print(url)
    return url
}

