//
//  ViewController.m
//  Battery Hub
//
//  Created by Simon Edwardes on 24/05/2016.
//  Copyright © 2016 Simon Edwardes. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
     //self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    PeripheralController *peripheralClass = [[PeripheralController alloc] init];
    [peripheralClass startAdvertising];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startScanning:(id)sender {
    CentralController *centralClass = [[CentralController alloc] init];
    [centralClass scan];
}

@end
