#import <AppKit/AppKit.h>

@interface BTSocialTextView : NSTextView

- (void) addItem:(NSString*)item withValue:(NSString*)value;
- (void) render;

@end

