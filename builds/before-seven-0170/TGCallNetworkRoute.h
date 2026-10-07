#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>

// iOS VPNs with an IPv4 tunnel can carry the Telegram relay traffic over
// the same path as the modern client's working call. Keep ICE's ordinary
// Wi-Fi socket available for direct connections.
static NSDictionary *TGCallIPv4VPNInterface(void) {
#if TARGET_OS_IPHONE
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0) return nil;
    unsigned int chosenIndex = 0;
    NSString *chosenAddress = nil;
    for (struct ifaddrs *item = list; item; item = item->ifa_next) {
        if (!item->ifa_addr || item->ifa_addr->sa_family != AF_INET ||
            !(item->ifa_flags & IFF_UP) || !(item->ifa_flags & IFF_POINTOPOINT)) continue;
        const char *name = item->ifa_name;
        if (!name || (strncmp(name, "utun", 4) && strncmp(name, "ppp", 3) &&
                      strncmp(name, "ipsec", 5))) continue;
        unsigned int index = if_nametoindex(name);
        if (!index || index <= chosenIndex) continue;
        char address[INET_ADDRSTRLEN];
        if (!inet_ntop(AF_INET, &((struct sockaddr_in *)item->ifa_addr)->sin_addr,
                       address, sizeof(address))) continue;
        chosenIndex = index;
        chosenAddress = [NSString stringWithUTF8String:address];
    }
    freeifaddrs(list);
    if (chosenIndex && chosenAddress) return @{ @"index": @(chosenIndex), @"address": chosenAddress };
#endif
    return nil;
}
