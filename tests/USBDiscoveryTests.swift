import Foundation
@main struct DiscoveryTests {
 static func main(){precondition(USBDiscovery.likely(vendor:0x10c4,product:0xea60));precondition(!USBDiscovery.likely(vendor:0x10c4,product:0));precondition(!USBDiscovery.likely(vendor:0,product:0xea60));precondition(!USBDiscovery.likely(vendor:-1,product:-1));print("USB descriptor matching tests passed; no ports opened.")}
}
