//
//  PeripheralController.m
//  Battery Hub
//
//  Created by Simon Edwardes on 25/05/2016.
//  Copyright © 2016 Simon Edwardes. All rights reserved.
//

#import "PeripheralController.h"
#define NOTIFY_MTU 20

@implementation PeripheralController

-(id)init{
    return [super init];
}

-(void)startAdvertising{
    NSLog(@"Start Advertising");
   // self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:(id<CBPeripheralManagerDelegate>)self queue:nil options:nil];
    //CBPeripheralManager *per = [[CBPeripheralManager alloc] initWithDelegate:(id<CBPeripheralManagerDelegate>)self queue:nil options:nil];
    
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"userID"];
    if(uuid == nil){
        NSString *newUUID = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:newUUID forKey:@"userID"];
        uuid = newUUID;
    }
    
    //[self.peripheralManager stopAdvertising];
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:uuid]] }];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    NSLog(@"...");
    if(peripheral.state == CBPeripheralManagerStatePoweredOff){
        //do something
    }
    // Opt out from any other state
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) return;
    // We're in CBPeripheralManagerStatePoweredOn state...
    NSLog(@"self.peripheralManager powered on.");
    // Start with the CBMutableCharacteristic
    self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@""]properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    // Then the service
    CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@""] primary:YES];
    // Add the characteristic to the service
    transferService.characteristics = @[self.transferCharacteristic];
    // And add it to the peripheral manager
    [self.peripheralManager addService:transferService];
    NSLog(@"Transfer Service Created");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"Central subscribed to characteristic");
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@""]]){
        NSLog(@"Central subscribed to characteristic %@", characteristic);
        self.sendDataIndex = 0;
        // Get the data
        UIDevice *myDevice = [UIDevice currentDevice];
        [myDevice setBatteryMonitoringEnabled:YES];
        float batteryLevel =[myDevice batteryLevel]*100;
        NSString *stringBattery = [NSString stringWithFormat:@"%0.0f%%", batteryLevel];
        self.dataToSend = [stringBattery dataUsingEncoding:NSUTF8StringEncoding];
        // Start sending
        [self sendData];
    }
}

- (void)sendData{
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    if (sendingEOM) {
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        if (didSend) {
            sendingEOM = NO;
            NSLog(@"Sent: EOM");
        }
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    BOOL didSend = YES;
    while (didSend) {
        // Work out how big it should be
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        // Send it
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) return;
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length) {
            // It was - send an EOM
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            // Send it
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                NSLog(@"Sent: EOM");
            }
            return;
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"Central unsubscribed from characteristic");
    [self.peripheralManager stopAdvertising];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral{
    [self sendData];
}

@end
