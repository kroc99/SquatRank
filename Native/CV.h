#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface CV : NSObject
- (void)initDetector;
- (NSArray*)detect: (CMSampleBufferRef)buffer;
- (NSArray*)detectCircles: (CMSampleBufferRef)buffer; // Add this if you need separate circle detection
@end

NS_ASSUME_NONNULL_END
