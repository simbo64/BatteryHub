//
//  CentralController.h
//  Battery Hub
//
//  Created by Simon Edwardes on 25/05/2016.
//  Copyright © 2016 Simon Edwardes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#define IDENTIFY_SERVICE_UUID           @"D20A39F4-73F5-4BC4-A12F-17D1AD07A961"
#define IDENTIFY_CHARACTERISTIC_UUID    @"D20A39F4-73F5-4BC4-A12F-17D1AD07A961"

@interface CentralController : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;

-(void)scan;

@end
