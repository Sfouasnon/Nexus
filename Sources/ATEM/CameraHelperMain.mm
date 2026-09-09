#import <Foundation/Foundation.h>

#include <cstdio>
#include <vector>

#include "BMDSwitcherAPI.h"

static void WriteJSON(NSDictionary *object)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data)
        return;
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static NSDictionary *ErrorMessage(NSString *message, HRESULT result)
{
    return @{
        @"type": @"error",
        @"message": message ?: @"Camera-control error.",
        @"code": @((int32_t)result),
    };
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 3 || strcmp(argv[1], "--address") != 0) {
            WriteJSON(ErrorMessage(@"Usage: ATEMCameraHelper --address <switcher>", E_INVALIDARG));
            return 2;
        }

        NSString *address = [NSString stringWithUTF8String:argv[2]] ?: @"";
        IBMDSwitcherDiscovery *discovery = CreateBMDSwitcherDiscoveryInstance();
        if (!discovery) {
            WriteJSON(ErrorMessage(@"Blackmagic Switcher runtime is unavailable.", E_FAIL));
            return 3;
        }

        IBMDSwitcher *switcher = nullptr;
        BMDSwitcherConnectToFailure failure = bmdSwitcherConnectToFailureNoResponse;
        HRESULT result = discovery->ConnectTo((__bridge CFStringRef)address, &switcher, &failure);
        if (FAILED(result) || !switcher) {
            WriteJSON(@{
                @"type": @"error",
                @"message": @"The isolated color engine could not connect to the ATEM.",
                @"code": @((int32_t)result),
                @"failure": @((uint32_t)failure),
            });
            discovery->Release();
            return 4;
        }

        IBMDSwitcherCameraControl *cameraControl = nullptr;
        result = switcher->QueryInterface(IID_IBMDSwitcherCameraControl, (void **)&cameraControl);
        if (FAILED(result) || !cameraControl) {
            WriteJSON(ErrorMessage(@"This switcher does not expose camera control.", result));
            switcher->Release();
            discovery->Release();
            return 5;
        }

        WriteJSON(@{@"type": @"ready", @"address": address});

        char *line = nullptr;
        size_t capacity = 0;
        while (getline(&line, &capacity, stdin) >= 0) {
            @autoreleasepool {
                NSString *commandLine = [[NSString alloc] initWithUTF8String:line] ?: @"";
                NSData *data = [commandLine dataUsingEncoding:NSUTF8StringEncoding];
                NSError *jsonError = nil;
                NSDictionary *command = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (![command isKindOfClass:NSDictionary.class]) {
                    WriteJSON(ErrorMessage(jsonError.localizedDescription ?: @"Invalid helper command.", E_INVALIDARG));
                    continue;
                }

                NSString *operation = command[@"op"];
                uint32_t camera = [command[@"camera"] unsignedIntValue];
                uint32_t parameter = [command[@"parameter"] unsignedIntValue];
                if (camera == 0 || parameter > 7) {
                    WriteJSON(ErrorMessage(@"Invalid camera or color parameter.", E_INVALIDARG));
                    continue;
                }

                if ([operation isEqualToString:@"reset"] && parameter == 7) {
                    result = cameraControl->SetFlags(camera, 8, 7, 0, nullptr);
                    if (FAILED(result))
                        WriteJSON(ErrorMessage(@"The camera rejected the color reset.", result));
                    else
                        WriteJSON(@{@"type": @"reset", @"camera": @(camera)});
                    continue;
                }

                const uint32_t expectedCounts[] = {4, 4, 4, 4, 2, 1, 2};
                if (parameter >= 7) {
                    WriteJSON(ErrorMessage(@"Invalid operation for the reset parameter.", E_INVALIDARG));
                    continue;
                }
                BMDSwitcherCameraControlParameterType parameterType =
                    bmdSwitcherCameraControlParameterTypeFixedPoint16Bit;
                uint32_t supportedCount = 0;
                HRESULT infoResult = cameraControl->GetParameterInfo(camera,
                                                                     8,
                                                                     parameter,
                                                                     &parameterType,
                                                                     &supportedCount);
                if (FAILED(infoResult) ||
                    parameterType != bmdSwitcherCameraControlParameterTypeFixedPoint16Bit ||
                    supportedCount != expectedCounts[parameter]) {
                    WriteJSON(ErrorMessage(@"This camera does not advertise support for that color control.",
                                           FAILED(infoResult) ? infoResult : E_NOINTERFACE));
                    continue;
                }

                if ([operation isEqualToString:@"get"]) {
                    uint32_t count = expectedCounts[parameter];
                    double values[4] = {0, 0, 0, 0};
                    result = cameraControl->GetFloats(camera, 8, parameter, &count, values);
                    if (FAILED(result)) {
                        WriteJSON(ErrorMessage(@"The camera did not return this color value.", result));
                        continue;
                    }
                    NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:count];
                    for (uint32_t index = 0; index < count; ++index)
                        [numbers addObject:@(values[index])];
                    WriteJSON(@{
                        @"type": @"values",
                        @"camera": @(camera),
                        @"parameter": @(parameter),
                        @"values": numbers,
                    });
                } else if ([operation isEqualToString:@"set"]) {
                    NSArray<NSNumber *> *numbers = command[@"values"];
                    if (![numbers isKindOfClass:NSArray.class] ||
                        numbers.count != expectedCounts[parameter]) {
                        WriteJSON(ErrorMessage(@"The color command has the wrong value count.", E_INVALIDARG));
                        continue;
                    }
                    double values[4] = {0, 0, 0, 0};
                    for (NSUInteger index = 0; index < numbers.count; ++index)
                        values[index] = numbers[index].doubleValue;
                    result = cameraControl->SetFloats(camera,
                                                      8,
                                                      parameter,
                                                      expectedCounts[parameter],
                                                      values);
                    if (FAILED(result)) {
                        WriteJSON(ErrorMessage(@"The camera rejected this color value.", result));
                        continue;
                    }
                    WriteJSON(@{
                        @"type": @"ack",
                        @"camera": @(camera),
                        @"parameter": @(parameter),
                    });
                } else {
                    WriteJSON(ErrorMessage(@"Unknown helper command.", E_INVALIDARG));
                }
            }
        }
        free(line);

        cameraControl->Release();
        switcher->Release();
        discovery->Release();
    }
    return 0;
}
