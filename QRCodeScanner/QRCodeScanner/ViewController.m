/*
 Copyright (c) 2014 Cristian Sava <cristianzsava@gmail.com>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/

#import "ViewController.h"
#import "ResultViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) IBOutlet UIView *captureView;

@property (readwrite, nonatomic) AVCaptureSession *captureSession;
@property (readwrite, nonatomic) NSString *lastQRCode;

@property (readwrite, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Used to enable sending notifications when the device orientation changes
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    self.captureSession = [[AVCaptureSession alloc] init];
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
    if( videoInput ) [self.captureSession addInput:videoInput];
    else
    {
        DLog( @"Error setting up the capture session : %@", error );
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Unexpected error while setting up the capture session." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alert show];
        
        return;
    }
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:metadataOutput];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    previewLayer.frame = self.captureView.layer.bounds;
    // Must set the gravity because of iPad, since it has a different aspect ratio
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer = previewLayer;
    [self.captureView.layer addSublayer:previewLayer];
}

- (void)viewWillAppear:(BOOL)animated
{
    if([[UIApplication sharedApplication] statusBarOrientation] != UIInterfaceOrientationPortrait)
        [self setUpCaptureView];
}

- (void)setUpCaptureViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    if(self.previewLayer.connection.supportsVideoOrientation)
    {
        switch(orientation)
        {
            case UIInterfaceOrientationPortrait:
            {
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
            }
                
            case UIInterfaceOrientationLandscapeLeft:
            {
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            }
                
            case UIInterfaceOrientationLandscapeRight:
            {
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            }
                
            default:
                break;
        }
    }
}

// If the controller is not initialized in Portrait, the capture view will not be displayed correctly
// Therefore force the correct transformation on the capture view
- (void)setUpCaptureView
{
    float rotation = 0.0f;
    
    if([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortraitUpsideDown) rotation = M_PI;
    else if([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationLandscapeLeft) rotation = M_PI / 2.0;
    else if([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationLandscapeRight) rotation = M_PI / (-2.0);
    
    if(rotation != 0.0f)
    {
        DLog( @"Capture view correctly rotated" );
        self.captureView.transform = CGAffineTransformMakeRotation(rotation);
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(![self.captureSession isRunning])
    {
        [self.captureSession startRunning];
        DLog(@"Starting capture...");
    }
}

// Exclude the capturing view from auto-rotation
- (void)orientationDidChange:(NSNotification *)notification
{
    DLog(@"Device orientation changed...");
    float rotation = 0.0f;
    
    UIInterfaceOrientation interfaceOrientationDevice = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
    
    //TODO disconsider the device orientation but use the status bar one instead for this case?
    // Ignore for example the horizontal positioning of the device
    if(interfaceOrientationDevice > 4) return;
    
    // Just ignore the upside-down orientation - device orientation is not in sync with the status bar one in this case
    if(interfaceOrientationDevice == UIInterfaceOrientationPortraitUpsideDown) return;
    else if(interfaceOrientationDevice == UIInterfaceOrientationLandscapeLeft) rotation = M_PI / 2.0;
    else if(interfaceOrientationDevice == UIInterfaceOrientationLandscapeRight) rotation = M_PI / (-2.0);
    
    // iOS rotation animation duration is 0.3
    // Same effect as in the camera app where controls do rotate and camera viewport don't
    float duration = rotation < M_PI / 2.0 ? 0.3 : 0.6;
    
    [UIView animateWithDuration:duration animations:^(void)
     {
         self.captureView.transform = CGAffineTransformMakeRotation( rotation );
     }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ShowCode"])
    {
        ResultViewController *resultVC = segue.destinationViewController;
        // The destination VC is a Navigation Controller, so target the next one in line
        if([segue.destinationViewController isKindOfClass:[UINavigationController class]])
            resultVC = [segue.destinationViewController viewControllers][0];
        
        resultVC.codeLabelText = self.lastQRCode;
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    for(AVMetadataObject *metadataObject in metadataObjects)
        if([metadataObject.type isEqualToString:AVMetadataObjectTypeQRCode])
        {
            AVMetadataMachineReadableCodeObject *codeObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
            DLog(@"Read an QR code with value = %@", codeObject.stringValue);
            self.lastQRCode = codeObject.stringValue;
            
            DLog(@"Stopping capture...");
            [self.captureSession stopRunning];
            
            [self performSegueWithIdentifier:@"ShowCode" sender:nil];
        }
}

@end
