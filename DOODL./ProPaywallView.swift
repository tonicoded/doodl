//
//  ProPaywallView.swift
//  DOODL.
//
//  Created by Anthony Verruijt on 17/12/2025.
//

import SwiftUI

struct ProPaywallView: View {
    let language: AppLanguage

    var body: some View {
        DoodlPaywallView(language: language, showsClose: true)
    }
}

