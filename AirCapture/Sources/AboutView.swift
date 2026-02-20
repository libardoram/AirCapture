// AirCapture - Multi-stream AirPlay receiver and recorder for macOS
// Copyright (C) 2026  Libardo Ramirez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//
// Source code: https://github.com/libardoram/AirCapture
// Binary available at: https://aircapture.eqmo.com

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLicense: LicenseItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "airplayvideo")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("AirCapture")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("AirPlay Screen Mirroring Receiver & Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            // Copyright & License
            VStack(spacing: 8) {
                Text("Copyright \u{00A9} 2026 Libardo Ramirez")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("This program comes with ABSOLUTELY NO WARRANTY.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("This is free software, and you are welcome to redistribute it under the terms of the GNU General Public License v3.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Link("Source Code", destination: URL(string: "https://github.com/libardoram/AirCapture")!)
                        .font(.caption2)
                    Link("Get Binary", destination: URL(string: "https://aircapture.eqmo.com")!)
                        .font(.caption2)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 12)
            
            Divider()
            
            // Third-party Licenses Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Third-Party Licenses")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                Text("This application uses the following open-source software:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(licenses) { license in
                            LicenseRow(license: license)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedLicense = license
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
            
            // Close Button
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
        }
        .frame(width: 600, height: 620)
        .sheet(item: $selectedLicense) { license in
            LicenseDetailView(license: license)
        }
    }
}

// MARK: - License Row

struct LicenseRow: View {
    let license: LicenseItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(license.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(license.licenseType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(licenseColor.opacity(0.2))
                    .foregroundColor(licenseColor)
                    .cornerRadius(4)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(license.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var licenseColor: Color {
        switch license.licenseType {
        case "GPL-3.0": return .orange
        case "MIT": return .green
        default: return .blue
        }
    }
}

// MARK: - License Detail View

struct LicenseDetailView: View {
    let license: LicenseItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(license.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(license.licenseType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // License Text
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let copyright = license.copyright {
                        Text(copyright)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                    
                    Text(license.fullLicenseText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - License Data Model

struct LicenseItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let licenseType: String
    let copyright: String?
    let fullLicenseText: String
}

// MARK: - License Data

private let licenses: [LicenseItem] = [
    LicenseItem(
        name: "UxPlay",
        description: "Open-source AirPlay server implementation for receiving AirPlay streams",
        licenseType: "GPL-3.0",
        copyright: "Copyright (C) 2011-2012 Juho Vähä-Herttua\nCopyright (C) 2021-2023 fduncanh",
        fullLicenseText: """
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007
        
        Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
        Everyone is permitted to copy and distribute verbatim copies
        of this license document, but changing it is not allowed.
        
        Preamble
        
        The GNU General Public License is a free, copyleft license for
        software and other kinds of works.
        
        The licenses for most software and other practical works are designed
        to take away your freedom to share and change the works. By contrast,
        the GNU General Public License is intended to guarantee your freedom to
        share and change all versions of a program--to make sure it remains free
        software for all its users. We, the Free Software Foundation, use the
        GNU General Public License for most of our software; it applies also to
        any other work released this way by its authors. You can apply it to
        your programs, too.
        
        When we speak of free software, we are referring to freedom, not
        price. Our General Public Licenses are designed to make sure that you
        have the freedom to distribute copies of free software (and charge for
        them if you wish), that you receive source code or can get it if you
        want it, that you can change the software or use pieces of it in new
        free programs, and that you know you can do these things.
        
        To protect your rights, we need to prevent others from denying you
        these rights or asking you to surrender the rights. Therefore, you have
        certain responsibilities if you distribute copies of the software, or if
        you modify it: responsibilities to respect the freedom of others.
        
        For the complete license text, see:
        https://www.gnu.org/licenses/gpl-3.0.txt
        
        This application uses UxPlay under the terms of the GPL-3.0 license.
        """
    ),
    
    LicenseItem(
        name: "llhttp",
        description: "High-performance HTTP parser used in AirPlay protocol handling",
        licenseType: "MIT",
        copyright: "Copyright Fedor Indutny, 2018",
        fullLicenseText: """
        MIT License
        
        Copyright Fedor Indutny, 2018.
        
        Permission is hereby granted, free of charge, to any person obtaining a
        copy of this software and associated documentation files (the
        "Software"), to deal in the Software without restriction, including
        without limitation the rights to use, copy, modify, merge, publish,
        distribute, sublicense, and/or sell copies of the Software, and to permit
        persons to whom the Software is furnished to do so, subject to the
        following conditions:
        
        The above copyright notice and this permission notice shall be included
        in all copies or substantial portions of the Software.
        
        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
        OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
        NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
        DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
        OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
        USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
    ),
    
    LicenseItem(
        name: "PlayFair",
        description: "FairPlay authentication library for AirPlay connections",
        licenseType: "GPL-3.0",
        copyright: nil,
        fullLicenseText: """
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007
        
        This library is licensed under the GNU General Public License version 3.
        
        For the complete license text, see:
        https://www.gnu.org/licenses/gpl-3.0.txt
        
        This application uses PlayFair under the terms of the GPL-3.0 license.
        """
    ),
    
    LicenseItem(
        name: "OpenSSL",
        description: "Cryptographic library for secure connections and encryption",
        licenseType: "Apache-2.0",
        copyright: "Copyright 1998-2024 The OpenSSL Project",
        fullLicenseText: """
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/
        
        Copyright 1998-2024 The OpenSSL Project
        
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at
        
            http://www.apache.org/licenses/LICENSE-2.0
        
        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
        """
    ),
    
    LicenseItem(
        name: "libplist",
        description: "Property list library for handling Apple's plist format",
        licenseType: "LGPL-2.1",
        copyright: "Copyright (C) 2008-2024 Jonathan Beck",
        fullLicenseText: """
        GNU LESSER GENERAL PUBLIC LICENSE
        Version 2.1, February 1999
        
        Copyright (C) 2008-2024 Jonathan Beck
        
        This library is free software; you can redistribute it and/or
        modify it under the terms of the GNU Lesser General Public
        License as published by the Free Software Foundation; either
        version 2.1 of the License, or (at your option) any later version.
        
        This library is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
        Lesser General Public License for more details.
        
        For the complete license text, see:
        https://www.gnu.org/licenses/lgpl-2.1.txt
        """
    )
]

// MARK: - Preview

#Preview {
    AboutView()
}
