// The MIT License (MIT)
//
// Copyright (c) 2013 l0gg3r
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "LGUtils.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import "LGBluetooth.h"

/**
 * Error domain for Write errors
 */
NSString * const kLGUtilsWriteErrorDomain = @"LGUtilsWriteErrorDomain";

/**
 * Global key for providing errors of LGBluetooth
 */
NSString * const kLGErrorMessageKey = @"msg";

/**
 * Error code for write operation
 * Service was not found on peripheral
 */
const NSInteger kLGUtilsMissingServiceErrorCode = 410;

/**
 * Error code for write operation
 * Characteristic was not found on peripheral
 */
const NSInteger kLGUtilsMissingCharacteristicErrorCode = 411;

/**
 * Error message for write operation
 * Service was not found on peripheral
 */
NSString * const kLGUtilsMissingServiceErrorMessage = @"Provided service UUID doesn't exist in provided pheripheral";

/**
 * Error message for write operation
 * Characteristic was not found on peripheral
 */
NSString * const kLGUtilsMissingCharacteristicErrorMessage = @"Provided characteristic doesn't exist in provided service";;

@implementation LGUtils

/*----------------------------------------------------*/
#pragma mark - Public Methods -
/*----------------------------------------------------*/

+ (void)writeData:(NSData *)aData
      charactUUID:(NSString *)aCharacteristic
       seriveUUID:(NSString *)aService
       peripheral:(LGPeripheral *)aPeripheral
       completion:(LGCharacteristicWriteCallback)aCallback
{
    if (aPeripheral.cbPeripheral.state == CBPeripheralStateConnected) {
        [self writeData:aData
            charactUUID:aCharacteristic
             seriveUUID:aService
        readyPeripheral:aPeripheral
             completion:aCallback];
    } else {
        [aPeripheral connectWithTimeout:30 completion:^(NSError *error) {
            [self writeData:aData
                charactUUID:aCharacteristic
                 seriveUUID:aService
            readyPeripheral:aPeripheral
                 completion:aCallback];
        }];
    }
}

+ (void)readDataFromCharactUUID:(NSString *)aCharacteristic
                     seriveUUID:(NSString *)aService
                     peripheral:(LGPeripheral *)aPeripheral
                     completion:(LGCharacteristicReadCallback)aCallback
{
    if (aPeripheral.cbPeripheral.state == CBPeripheralStateConnected) {
        [self readDataFromCharactUUID:aCharacteristic
                           seriveUUID:aService
                      readyPeripheral:aPeripheral
                           completion:aCallback];
    } else {
        [aPeripheral connectWithTimeout:30 completion:^(NSError *error) {
            [self readDataFromCharactUUID:aCharacteristic
                               seriveUUID:aService
                          readyPeripheral:aPeripheral
                               completion:aCallback];
        }];
    }
}

/*----------------------------------------------------*/
#pragma mark - Private Methods -
/*----------------------------------------------------*/

+ (void)writeData:(NSData *)aData
      charactUUID:(NSString *)aCharacteristic
       seriveUUID:(NSString *)aService
  readyPeripheral:(LGPeripheral *)aPeripheral
       completion:(LGCharacteristicWriteCallback)aCallback;
{
    [aPeripheral discoverServices:@[[CBUUID UUIDWithString:aService]] completion:^(NSArray *services, NSError *error) {
        LGService *service = nil;
        if (services.count && !error && (service = [self findServiceInList:services byUUID:aService])) {
            [service discoverCharacteristicsWithUUIDs:@[[CBUUID UUIDWithString:aCharacteristic]]
                                           completion:^(NSArray *characteristics, NSError *error)
            {
                LGCharacteristic *characteristic = nil;
                if (characteristics.count && (characteristic = [self findCharacteristicInList:characteristics byUUID:aCharacteristic])) {
                    [characteristic writeValue:aData completion:aCallback];
                } else {
                    if (aCallback) {
                        if (!error) {
                            aCallback([LGUtils writeErrorWithCode:kLGUtilsMissingCharacteristicErrorCode
                                                          message:kLGUtilsMissingCharacteristicErrorMessage]);
                        } else {
                            aCallback(error);
                        }
                    }
                    LGLogError(@"Missing provided characteristic : %@ in service : %@", aCharacteristic, aService);
                }
            }];
        } else {
            if (aCallback) {
                if (!error) {
                    aCallback([LGUtils writeErrorWithCode:kLGUtilsMissingServiceErrorCode
                                                  message:kLGUtilsMissingServiceErrorMessage]);
                } else {
                    aCallback(error);
                }
            }
            LGLogError(@"Missing provided service : %@ in peripheral", aService);
        }
    }];
}

+ (void)readDataFromCharactUUID:(NSString *)aCharacteristic
                     seriveUUID:(NSString *)aService
                readyPeripheral:(LGPeripheral *)aPeripheral
                     completion:(LGCharacteristicReadCallback)aCallback;
{
    [aPeripheral discoverServices:@[[CBUUID UUIDWithString:aService]] completion:^(NSArray *services, NSError *error) {
        if (services.count && !error) {
            LGService *service = [self findServiceInList:services
                                                  byUUID:aService];
            [service discoverCharacteristicsWithUUIDs:@[[CBUUID UUIDWithString:aCharacteristic]] completion:^(NSArray *characteristics, NSError *error) {
                if (characteristics.count) {
                    LGCharacteristic *characteristic = [self findCharacteristicInList:characteristics
                                                                               byUUID:aCharacteristic];
                    [characteristic readValueWithBlock:aCallback];
                } else {
                    if (aCallback) {
                        if (!error) {
                            aCallback(nil, [LGUtils writeErrorWithCode:kLGUtilsMissingCharacteristicErrorCode
                                                               message:kLGUtilsMissingCharacteristicErrorMessage]);
                        } else {
                            aCallback(nil, error);
                        }
                    }
                }
            }];
        } else {
            if (aCallback) {
                if (!error) {
                    aCallback(nil, [LGUtils writeErrorWithCode:kLGUtilsMissingServiceErrorCode
                                                       message:kLGUtilsMissingServiceErrorMessage]);
                } else {
                    aCallback(nil, error);
                }
            }
        }
    }];
}

/**
 * Find characteristic in characteristic list by providied UUID string
 * @return Found characteristic, nil if no one found
 */
+ (LGCharacteristic *)findCharacteristicInList:(NSArray *)characteristics
                                        byUUID:(NSString *)anID
{
    for (LGCharacteristic *characteristic in characteristics) {
        if ([[characteristic.UUIDString lowercaseString] isEqualToString:[anID lowercaseString]]) {
            return characteristic;
        }
    }
    return nil;
}

/**
 * Find service in services list by providied UUID string
 * @return Found service, nil if no one found
 */
+ (LGService *)findServiceInList:(NSArray *)services
                                 byUUID:(NSString *)anID
{
    for (LGService *service in services) {
        if ([[service.UUIDString lowercaseString] isEqualToString:[anID lowercaseString]]) {
            return service;
        }
    }
    return nil;
}

/*----------------------------------------------------*/
#pragma mark - Error Generators -
/*----------------------------------------------------*/

+ (NSError *)writeErrorWithCode:(NSInteger)aCode message:(NSString *)aMsg
{
    return [NSError errorWithDomain:kLGUtilsWriteErrorDomain
                               code:aCode
                           userInfo:@{kLGErrorMessageKey : aMsg}];
}



@end
