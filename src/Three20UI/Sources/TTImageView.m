//
// Copyright 2009-2011 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "Three20UI/TTImageView.h"

#import "Three20Core/TTGlobalCorePaths.h"

// UI
#import "Three20UI/TTImageViewDelegate.h"

// UI (private)
#import "Three20UI/private/TTImageLayer.h"
#import "Three20UI/private/TTImageViewInternal.h"

// Style
#import "Three20Style/TTShape.h"
#import "Three20Style/TTStyleContext.h"
#import "Three20Style/TTContentStyle.h"

// Network
#import "Three20Network/TTURLCache.h"
#import "Three20Network/TTURLImageResponse.h"
#import "Three20Network/TTURLRequest.h"

#import <AssetsLibrary/AssetsLibrary.h>


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TTImageView

@synthesize urlPath             = _urlPath;
@synthesize image               = _image;
@synthesize defaultImage        = _defaultImage;
@synthesize autoresizesToImage  = _autoresizesToImage;

@synthesize delegate = _delegate;
@synthesize assetImageSize = _assetImageSize;

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _autoresizesToImage = NO;
    self.assetImageSize = TTALAssetImageSizeFullResolution;
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  _delegate = nil;
  [_request cancel];
  TT_RELEASE_SAFELY(_request);
  TT_RELEASE_SAFELY(_urlPath);
  TT_RELEASE_SAFELY(_image);
  TT_RELEASE_SAFELY(_defaultImage);
  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIView


///////////////////////////////////////////////////////////////////////////////////////////////////
+ (Class)layerClass {
  return [TTImageLayer class];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)drawRect:(CGRect)rect {
  if (self.style) {
    [super drawRect:rect];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTView


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)drawContent:(CGRect)rect {
  if (nil != _image) {
    [_image drawInRect:rect contentMode:self.contentMode];

  } else {
    [_defaultImage drawInRect:rect contentMode:self.contentMode];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTURLRequestDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidStartLoad:(TTURLRequest*)request {
  [_request release];
  _request = [request retain];

  [self imageViewDidStartLoad];
  if ([_delegate respondsToSelector:@selector(imageViewDidStartLoad:)]) {
    [_delegate imageViewDidStartLoad:self];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidFinishLoad:(TTURLRequest*)request {
  TTURLImageResponse* response = request.response;
  [self setImage:response.image];

  TT_RELEASE_SAFELY(_request);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)request:(TTURLRequest*)request didFailLoadWithError:(NSError*)error {
  TT_RELEASE_SAFELY(_request);

  [self imageViewDidFailLoadWithError:error];
  if ([_delegate respondsToSelector:@selector(imageView:didFailLoadWithError:)]) {
    [_delegate imageView:self didFailLoadWithError:error];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidCancelLoad:(TTURLRequest*)request {
  TT_RELEASE_SAFELY(_request);

  [self imageViewDidFailLoadWithError:nil];
  if ([_delegate respondsToSelector:@selector(imageView:didFailLoadWithError:)]) {
    [_delegate imageView:self didFailLoadWithError:nil];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTStyleDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)drawLayer:(TTStyleContext*)context withStyle:(TTStyle*)style {
  if ([style isKindOfClass:[TTContentStyle class]]) {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);

    CGRect rect = context.frame;
    [context.shape addToPath:rect];
    CGContextClip(ctx);

    [self drawContent:rect];

    CGContextRestoreGState(ctx);
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTURLRequestDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isLoading {
  return !!_request;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isLoaded {
  return nil != _image && _image != _defaultImage;
}

- (UIImage *)image:(UIImage *)image rotateInRadians:(CGFloat)radians {
	CGImageRef cgImage = image.CGImage;
	const CGFloat originalWidth = CGImageGetWidth(cgImage);
	const CGFloat originalHeight = CGImageGetHeight(cgImage);
	
	const CGRect imgRect = (CGRect){
        .origin.x = 0.0f,
        .origin.y = 0.0f,
        .size.width = originalWidth,
        .size.height = originalHeight};
	const CGRect rotatedRect = CGRectApplyAffineTransform(imgRect,
                                                          CGAffineTransformMakeRotation(radians));
	
	/// Create an ARGB bitmap context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	/// Create the bitmap context, we want pre-multiplied ARGB, 8-bits per component
	CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                   rotatedRect.size.width,
                                                   rotatedRect.size.height,
                                                   8/*Bits per component*/,
                                                   0, //bytesPerRow
                                                   colorSpace,
                                                   kCGBitmapByteOrderDefault |
                                                   kCGImageAlphaPremultipliedFirst);
	
	CGColorSpaceRelease(colorSpace);
	
	if (!bmContext)
		return nil;
	
	/// Image quality
	CGContextSetShouldAntialias(bmContext, true);
	CGContextSetAllowsAntialiasing(bmContext, true);
	CGContextSetInterpolationQuality(bmContext, kCGInterpolationHigh);
	
	/// Rotation happen here
	CGContextTranslateCTM(bmContext,
                          +(rotatedRect.size.width * 0.5f),
                          +(rotatedRect.size.height * 0.5f));
	CGContextRotateCTM(bmContext, radians);
	
	/// Draw the image in the bitmap context
	CGContextDrawImage(bmContext, (CGRect){
        .origin.x = -originalWidth * 0.5f,
        .origin.y = -originalHeight * 0.5f,
        .size.width = originalWidth,
        .size.height = originalHeight}, cgImage);
	
	/// Create an image object from the context
	CGImageRef rotatedImageRef = CGBitmapContextCreateImage(bmContext);
	UIImage* rotated = [UIImage imageWithCGImage:rotatedImageRef];
	
	/// Cleanup
	CGImageRelease(rotatedImageRef);
	CGContextRelease(bmContext);
	
	return rotated;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)reload {
  if (nil == _request && nil != _urlPath) {
    UIImage* image = [[TTURLCache sharedCache] imageForURL:_urlPath];

    if (nil != image) {
    
      self.image = image;

    } else {
		if (TTIsWebURL(_urlPath)) {
		  TTURLRequest* request = [TTURLRequest requestWithURL:_urlPath delegate:self];
		  request.response = [[[TTURLImageResponse alloc] init] autorelease];

		  if (![request send]) {
			// Put the default image in place while waiting for the request to load
			if (_defaultImage && nil == self.image) {
			  self.image = _defaultImage;
			}
		  }
		}
		else if (TTIsAssetsLibraryURL(_urlPath)) {
			ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
			
			[self imageViewDidStartLoad];
			if ([_delegate respondsToSelector:@selector(imageViewDidStartLoad:)]) {
				[_delegate imageViewDidStartLoad:self];
			}
					
			[library assetForURL:[NSURL URLWithString:_urlPath]
					 resultBlock:^(ALAsset *asset) {
						 // Sadly, the code initWithCGImage:scale:orientation: method doesn't work
//						 ALAssetRepresentation *representation = [asset defaultRepresentation]
//						 CGImageRef imageRef = [representation fullScreenImage];
//						 // TODO: Tweak the scale?
//						 UIImage *imageForAsset = [[[UIImage alloc] initWithCGImage:imageRef scale:1.0 orientation:representation.orientation] autorelease];

						 // Instead we use this helper:
                         self.image = [UIImage imageFromALAsset:asset forImageSize:self.assetImageSize];

						 [self imageViewDidLoadImage:self.image];
						 if ([_delegate respondsToSelector:@selector(imageView:didLoadImage:)]) {
							 [_delegate imageView:self didLoadImage:self.image];
						 }
						 
						 [library release];
							
					 } failureBlock:^(NSError *error) {
						 
						 [self imageViewDidFailLoadWithError:error];
						 if ([_delegate respondsToSelector:@selector(imageView:didFailLoadWithError:)]) {
							 [_delegate imageView:self didFailLoadWithError:error];
						 }
						 
						 [library release];
					 }];			
		}
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)stopLoading {
  [_request cancel];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)imageViewDidStartLoad {
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)imageViewDidLoadImage:(UIImage*)image {
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)imageViewDidFailLoadWithError:(NSError*)error {
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark public


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)unsetImage {
  [self stopLoading];
  self.image = nil;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setDefaultImage:(UIImage*)theDefaultImage {
  if (_defaultImage != theDefaultImage) {
    [_defaultImage release];
    _defaultImage = [theDefaultImage retain];
  }
  if (nil == _urlPath || 0 == _urlPath.length) {
    //no url path set yet, so use it as the current image
    self.image = _defaultImage;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setUrlPath:(NSString*)urlPath {
  // Check for no changes.
  if (nil != _image && nil != _urlPath && [urlPath isEqualToString:_urlPath]) {
    return;
  }

  [self stopLoading];

  {
    NSString* urlPathCopy = [urlPath copy];
    [_urlPath release];
    _urlPath = urlPathCopy;
  }

  if (nil == _urlPath || 0 == _urlPath.length) {
    // Setting the url path to an empty/nil path, so let's restore the default image.
    self.image = _defaultImage;

  } else {
    [self reload];
  }
}


@end
