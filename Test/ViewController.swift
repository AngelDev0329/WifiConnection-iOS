//
//  ViewController.swift
//  Test
//
//  Created by AngelDev on 5/14/20.
//  Copyright © 2020 AngelDev. All rights reserved.
//

import UIKit

import NetworkExtension

class ViewController: UIViewController {

    @IBOutlet weak var lblMyIpAddr: UILabel!
    @IBOutlet weak var txvIPAddrs: UITextView!
    
    let strSSID = "5022"
    let strPassword = "PasswordIs5022"
    let isWEP = false
    var manager = NEHotspotConfigurationManager.shared
    var hotspotConfiguration = NEHotspotConfiguration()
    
    var method: Network?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        hotspotConfiguration = NEHotspotConfiguration(ssid: strSSID, passphrase: strPassword, isWEP: isWEP)
        hotspotConfiguration.joinOnce = false
        hotspotConfiguration.lifeTimeInDays = 1
        
        method = .wifi
        manager = NEHotspotConfigurationManager.shared
        manager.apply(hotspotConfiguration) { (error) in
            if error != nil {
                if error?.localizedDescription == "already associated." {
                    let friends = self.getIFAddresses()
                    
                    self.lblMyIpAddr.text = self.getMyAddress(for: self.method!)
                    
                    self.txvIPAddrs.text = self.txvIPAddrs.text + ":::count===>\(friends.count)"
                    for one in friends {
                        self.txvIPAddrs.text = self.txvIPAddrs.text + ":::\n" + one
                    }
                    
                    let str = self.getIPAddressForCellOrWireless() ?? "Empty"
                    
                    self.showAlertString(str)
                    
                }
                else{
                    print("No Connected")
                }
            }
            else {
                let friends = self.getIFAddresses()
                
                self.lblMyIpAddr.text = self.getMyAddress(for: self.method!)
                
                self.txvIPAddrs.text = self.txvIPAddrs.text + ":::count===>\(friends.count)"
                for one in friends {
                    self.txvIPAddrs.text = self.txvIPAddrs.text + ":::\n" + one
                }
            }
        }
    }
    
    @IBAction func connectAction(_ sender: UIButton) {

        manager.apply(hotspotConfiguration) { (error) in
            if error != nil {
                self.showError(error: error!)
                
                if error?.localizedDescription == "already associated." {
                    print("Connected")
                    print("wifi: \(String(describing: self.getMyAddress(for: self.method!)!))")
                    
                    self.lblMyIpAddr.text = self.getMyAddress(for: self.method!)
                    self.showSuccess()
                    
                    let friends = self.getIFAddresses()
                    for one in friends {
                        self.txvIPAddrs.text = self.txvIPAddrs.text + "\n" + one
                    }
                }
                else{
                    print("No Connected")
                }
            }
            else {
                
                let myIP = self.getMyAddress(for: self.method!)
                print("wifi: \(String(describing: myIP!))")
                self.lblMyIpAddr.text = myIP
                
                let friends = self.getIFAddresses()
                for one in friends {
                    self.txvIPAddrs.text = self.txvIPAddrs.text + "\n" + one
                }
                
                let str = self.getIPAddressForCellOrWireless() ?? "Empty"
                
                self.showAlertString(str)
                self.showSuccess()
            }
        }
        
    }
    
    @IBAction func disconnectAction(_ sender: Any) {
        manager.removeConfiguration(forSSID: strSSID)
        self.lblMyIpAddr.text = ""
    }
    
    private func showError(error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK-Darn", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func showSuccess() {
        let alert = UIAlertController(title: "", message: "Connected", preferredStyle: .alert)
        let action = UIAlertAction(title: "Cool", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func showAlertString(_ str: String) {
        let alert = UIAlertController(title: "", message: str, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    
    

    enum Network: String {
        case wifi = "en0"
        case cellular = "pdp_ip0"
        case ipv4 = "ipv4"
        case ipv6 = "ipv6"
    }

    func getMyAddress(for network: Network) -> String? {
        var address: String?

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == network.rawValue {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        print("ifaddr===>", ifaddr!)
        print("address===>", address!)
        freeifaddrs(ifaddr)

        return address
    }
    
    func getIPAddressForCellOrWireless()-> String? {

        let WIFI_IF : [String] = ["en0"]
        let KNOWN_WIRED_IFS : [String] = ["en2", "en3", "en4"]
        let KNOWN_CELL_IFS : [String] = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

        var addresses : [String : String] = ["wireless":"",
                                             "wired":"",
                                             "cell":""]

        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {

            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next } // memory has been renamed to pointee in swift 3 so changed memory to pointee

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    if let name: String = String(cString: (interface?.ifa_name)!), (WIFI_IF.contains(name) || KNOWN_WIRED_IFS.contains(name) || KNOWN_CELL_IFS.contains(name)) {

                        // String.fromCString() is deprecated in Swift 3. So use the following code inorder to get the exact IP Address.
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        if WIFI_IF.contains(name){
                            addresses["wireless"] =  address
                        }else if KNOWN_WIRED_IFS.contains(name){
                            addresses["wired"] =  address
                        }else if KNOWN_CELL_IFS.contains(name){
                            addresses["cell"] =  address
                        }
                    }

                }
            }
        }
        freeifaddrs(ifaddr)

        var ipAddressString : String?
        let wirelessString = addresses["wireless"]
        let wiredString = addresses["wired"]
        let cellString = addresses["cell"]
        if let wirelessString = wirelessString, wirelessString.count > 0{
            ipAddressString = wirelessString
        }else if let wiredString = wiredString, wiredString.count > 0{
            ipAddressString = wiredString
        }else if let cellString = cellString, cellString.count > 0{
            ipAddressString = cellString
        }
        return ipAddressString
    }
    /*
    func getIFAddresses() -> [String] {
        
        let network: Network = .wifi
        
        var addresses = [String]()
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            /*
            let flags = Int32(ifptr.pointee.ifa_flags)
            let addr = ifptr.pointee.ifa_addr.pointee
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ifptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }*/
            
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == network.rawValue {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, socklen_t(0), NI_NUMERICHOST
                    )
//                    address = String(cString: hostname)
                    let address = String(cString: hostname)
                    addresses.append(address)
                }
            }
        }
        freeifaddrs(ifaddr)
        return addresses
    }
    */
    
    
    func getIFAddresses() -> [String] {
        var addresses = [String]()
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return addresses
    }

}
