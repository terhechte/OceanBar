#import "BTSocialTextView.h"

NSString * const kItemFontName = @"Lucida Grande";
NSString * const kValueFontName = @"Lucida Grande Bold";
static const NSUInteger kItemFontSize = 16;
static const NSUInteger kLeftSideIndent = 5;
static const NSUInteger kLineSpacing = 3;
static const NSUInteger kTabStopWidth = 80;


@interface BTSocialTextView()
{
    NSMutableArray *_keyStorage;
    NSMutableArray *_valueStorage;
    NSTrackingArea *_trackingArea;
}

@end

//--------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Main Class
//--------------------------------------------------------------------------------------

@implementation BTSocialTextView

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _keyStorage = @[].mutableCopy;
        _valueStorage = @[].mutableCopy;
        
        [self setDrawsBackground:NO];
        
        _trackingArea = [[NSTrackingArea alloc]initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
        [self addTrackingArea:_trackingArea];
    }
    return self;
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)flag {
    // we don't want selection
}

-(void)drawInsertionPointInRect:(NSRect)aRect color:(NSColor *)aColor turnedOn:(BOOL)flag {
    // we don't want an insertion cursor
}

- (void)mouseMoved:(NSEvent *)event {
    // we want the default arrow cursor
    [[NSCursor arrowCursor] set];
}

- (void)drawRect:(NSRect)rect {
    [[NSColor gridColor] setFill];
    NSRectFill(rect);
    
    // draw the gray area for the keys
    NSRect drawRect = NSMakeRect(0, 0, kTabStopWidth, rect.size.height);
    [[NSColor controlHighlightColor] setFill];
    NSRectFill(drawRect);
    
    [super drawRect:rect];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

//--------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Public Interface
//--------------------------------------------------------------------------------------

- (void) addItem:(NSString*)item withValue:(NSString*)value {
    [_keyStorage addObject:item];
    [_valueStorage addObject:value];
}

- (void) render {
    [self setEditable:YES];
    
    [self setString:@""];
    
    for (NSString *key in _keyStorage.reverseObjectEnumerator.allObjects) {
        [self renderItem:key
               withValue:_valueStorage[[_keyStorage indexOfObject:key]]];
    }
    
    [[[self enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0, 0)];
    
    [self setEditable:NO];
}

//-----------------------------------------------------------------------------
#pragma mark Private
//-----------------------------------------------------------------------------

- (void) renderItem:(NSString*)item withValue:(NSString*)value {
    
    NSDictionary *valueTextAttributes =
    @{NSFontAttributeName: [NSFont fontWithName: kValueFontName size: kItemFontSize],
      NSForegroundColorAttributeName: [NSColor blackColor]};
    
    // by replacing breaks with breaktabs, we can keep the indent
    NSAttributedString *valueString =
    [[NSAttributedString alloc]
     initWithString:[value stringByReplacingOccurrencesOfString:@"\n"
                                                     withString:@"\n\t"]
     attributes:valueTextAttributes];
    
    NSFont *itemFont = [NSFont fontWithName:kItemFontName size:kItemFontSize];
    
    NSString *tabbedItemFont = [item stringByAppendingString:@"\t"];
    
    NSMutableAttributedString *mutableString = [valueString mutableCopy];
    [mutableString insertAttributedString:
     [[NSAttributedString alloc] initWithString:
      [NSString stringWithFormat:@"%@", tabbedItemFont]]
                                  atIndex:0];
    [mutableString appendAttributedString:
     [[NSAttributedString alloc] initWithString:@"\n\n"]];
    
    NSMutableParagraphStyle *paragStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    //[paragStyle setAlignment:NSLeftTextAlignment]; // default, but just in case
    [paragStyle setLineSpacing:kLineSpacing];
    
    // Define a tab stop to the right of the bullet glyph.
    NSTextTab *textTabFllwgBullet = [[NSTextTab alloc] initWithType:NSLeftTabStopType
                                                           location:kTabStopWidth];
    [paragStyle setTabStops:[NSArray arrayWithObject:textTabFllwgBullet]];
    
    // Indent the first line up to where the bullet should appear.
    [paragStyle setFirstLineHeadIndent:kLeftSideIndent];
    
    // Set the indentation for the wrapped lines to the same place as the tab stop.
    [paragStyle setHeadIndent:kTabStopWidth];
    
    // set the attributes
    [mutableString setAttributes:@{NSParagraphStyleAttributeName: paragStyle,
                                   NSFontAttributeName: itemFont}
                           range:NSMakeRange(0, mutableString.length)];
    
    // Set the text color for the headline
    [mutableString setAttributes:@{NSFontAttributeName: itemFont,
                           NSForegroundColorAttributeName: [NSColor darkGrayColor],
                                   NSParagraphStyleAttributeName: paragStyle}
                           range:NSMakeRange(0, [tabbedItemFont length])];
    
    [self insertText:mutableString];
}

@end
