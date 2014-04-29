#import "BTSocialTextView.h"

NSString * const kItemFontName = @"Lucida Grande";
NSString * const kValueFontName = @"Lucida Grande Bold";
static const NSUInteger kItemFontSize = 16;
static const NSUInteger kLeftSideIndent = 5;
static const NSUInteger kLineSpacing = 3;
static const NSUInteger kTabStopWidth = 80;


@interface BTSocialTextView()
{
    NSMutableDictionary* _storage;
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
        _storage = [NSMutableDictionary dictionary];
        
        [self setDrawsBackground:NO];
    }
    return self;
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)flag
{
    
}

-(void)drawInsertionPointInRect:(NSRect)aRect color:(NSColor *)aColor turnedOn:(BOOL)flag {
    
}

- (void)drawRect:(NSRect)rect
{
    [[NSColor gridColor] setFill];
    NSRectFill(rect);
    
    // draw the gray area for the keys
    NSRect drawRect = NSMakeRect(0, 0, kTabStopWidth, rect.size.height);
    [[NSColor controlHighlightColor] setFill];
    NSRectFill(drawRect);
    
    [super drawRect:rect];
}

- (void) addItem:(NSString*)item withValue:(NSString*)value {
    _storage[item] = value;
}

//--------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Public Interface
//--------------------------------------------------------------------------------------

- (void) render {
    [self setEditable:YES];
    
    [self setString:@""];
    
    for (NSString *key in [_storage allKeys]) {
        [self renderItem:key withValue:_storage[key]];
    }
    
    [[[self enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0, 0)];
    
    [self setEditable:NO];
}

- (void) renderItem:(NSString*)item withValue:(NSString*)value {
    NSAttributedString *valueString =
    [[NSAttributedString alloc] initWithString:value
                                    attributes:[self defaultTextStyleWithColor:
                                                [NSColor blackColor]]];
    
    [self insertAttributedStringParagraph:valueString withHeadline:item];
}

- (NSDictionary*) defaultTextStyleWithColor:(NSColor*)color {
    NSDictionary* tokenFontAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont fontWithName: kValueFontName size: kItemFontSize], NSFontAttributeName,
                                         color, NSForegroundColorAttributeName, nil];
    return tokenFontAttributes;
}

- (void)insertAttachmentCell:(NSTextAttachmentCell *)cell toTextView:(NSTextView *)textView
{
    NSTextAttachment *attachment = [NSTextAttachment new];
    [attachment setAttachmentCell:cell];
    [textView insertText:[NSAttributedString attributedStringWithAttachment:attachment]];
}

- (void) insertAttributedStringParagraph:(NSAttributedString*)aString withHeadline:(NSString*)glyph {
    
    NSFont *glyphFont = [NSFont fontWithName:kItemFontName size:kItemFontSize];
    
    NSString *stringWithGlyphPlusSpace = [glyph stringByAppendingString:@"\t"];
    
    NSMutableAttributedString *mutableString = [aString mutableCopy];
    [mutableString insertAttributedString:
     [[NSAttributedString alloc] initWithString:
      [NSString stringWithFormat:@"\n\n%@", stringWithGlyphPlusSpace]]
                                  atIndex:0];
    
    NSMutableParagraphStyle *paragStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragStyle setAlignment:NSLeftTextAlignment]; // default, but just in case
    [paragStyle setLineSpacing:kLineSpacing];
    
    // Define a tab stop to the right of the bullet glyph.
    NSTextTab *textTabFllwgBullet = [[NSTextTab alloc] initWithType:NSLeftTabStopType
                                                           location:kTabStopWidth];
    [paragStyle setTabStops:[NSArray arrayWithObject:textTabFllwgBullet]];
    
    // Indent the first line up to where the bullet should appear.
    [paragStyle setFirstLineHeadIndent:kLeftSideIndent];
    
    // Set the indentation for the wrapped lines to the same place as the tab stop.
    [paragStyle setHeadIndent:kTabStopWidth];
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          glyphFont, NSFontAttributeName,
                          [NSColor darkGrayColor], NSForegroundColorAttributeName,
                          paragStyle, NSParagraphStyleAttributeName,
                          nil];
    
    // Use the attributes dictionary to make an attributed string out of the plain string.
    [mutableString setAttributes:dict range:NSMakeRange(0, [stringWithGlyphPlusSpace length] + 1)];
    
    [self insertText:mutableString];
}

@end
