//
//  SetteingModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/2/25.
//

import Foundation
import SwiftUI

struct SettingModel: Identifiable{
    var id = UUID()
    var titleSetting: String
    var selectedView: AnyView
}
