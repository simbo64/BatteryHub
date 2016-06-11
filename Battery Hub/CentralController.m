//
//  CentralController.m
//  Battery Hub
//
//  Created by Simon Edwardes on 25/05/2016.
//  Copyright © 2016 Simon Edwardes. All rights reserved.
//

#import "CentralController.h"
#define NOTIFY_MTU      20

@implementation CentralController

-(id)init{
    return [super init];
}
/////////////////////
- (void)scan{
    NSLog(@"Scan for other advertisers");
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"AAAAAAAA"]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey :@YES }];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered %@ at %@ %@", peripheral.name, RSSI, peripheral.identifier.UUIDString);
    
    // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
    self.discoveredPeripheral = peripheral;
    
    // And connect
    NSLog(@"Connecting to peripheral %@", peripheral);
    [self.centralManager connectPeripheral:peripheral options:nil];
    [self.centralManager stopScan];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    [self scan];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"Peripheral Connected");
    // Stop scanning
    [self.centralManager stopScan];
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:IDENTIFY_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    NSLog(@"BluCom Peripheral Discovered");
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    // Discover the characteristic we want...
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:IDENTIFY_CHARACTERISTIC_UUID]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    NSLog(@"Peripheral Details Connected");
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:IDENTIFY_CHARACTERISTIC_UUID]]) {
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    // Have we got everything we need?
    //if ([stringFromData isEqualToString:@"EOM"]) {
    NSMutableArray *storedID = [[NSMutableArray alloc] init];
    storedID = [[[NSUserDefaults standardUserDefaults] objectForKey:@"IDStore"]mutableCopy];
    for (int i=0; i<storedID.count; i++) {
        NSString *ID = [[[storedID objectAtIndex:i] componentsSeparatedByString:@"*"] objectAtIndex:1];
        if ([ID containsString: stringFromData]) {
            
            // And connect
            NSLog(@"Connecting to peripheral %@", peripheral);
        }
    }
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
    // Log it
    NSLog(@"Received: %@", stringFromData);
}

- (void)cleanup{
    // Don't do anything if we're not connected
    if (CBPeripheralStateDisconnected)  return;
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:IDENTIFY_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

@end
