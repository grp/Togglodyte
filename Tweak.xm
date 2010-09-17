
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#define TOGGLE_PATH @"/var/mobile/Library/SBSettings/Toggles/"

typedef void *callback_t;

@interface TDToggle : NSObject {
	void *dylib;
	callback_t is_capable;
	callback_t is_enabled;
	callback_t get_state_fast;
	callback_t set_state;
	callback_t get_delay_time;
	callback_t allow_in_call;
	callback_t invoke_hold_action;
	callback_t close_window;
	
	BOOL visible;
	BOOL enabled;
	NSString *name;
	NSString *path;
}

@end

@implementation TDToggle

- (BOOL)isCapable {
	return is_capable != NULL && ((BOOL (*)(void)) is_capable)();
}

- (BOOL)isEnabled {
	return is_enabled != NULL && ((BOOL (*)(void)) is_enabled)();
}

- (BOOL)getStateFast {
	return get_state_fast != NULL && ((BOOL (*)(void)) get_state_fast)();
}

- (void)setState:(BOOL)state {
	((void (*)(BOOL)) set_state)(state);
}

- (float)getDelayTime {
	return get_delay_time != NULL && ((float (*)(void)) get_delay_time)();
}

- (BOOL)allowInCall {
	return allow_in_call != NULL && ((BOOL (*)(void)) allow_in_call)();
}

- (void)invokeHoldAction {
	((void (*)(void)) invoke_hold_action)();
}

- (void)closeWindow {
	((void (*)(void)) close_window)();
}

- (id)icon {
	if ([self isEnabled])
	return [UIImage imageWithContentsOfFile:[@"/var/mobile/Library/SBSettings/Themes/HUD/" stringByAppendingFormat:@"%@/on.png", name]];
	else
	return [UIImage imageWithContentsOfFile:[@"/var/mobile/Library/SBSettings/Themes/HUD/" stringByAppendingFormat:@"%@/off.png", name]];
}

- (id)initWithName:(NSString *)n path:(NSString *)p {
	if ((self = [super init])) {
		path = [p copy];
		name = [n copy];
		 
		NSString *togglePath = [path stringByAppendingString:@"/Toggle.dylib"];
		dylib = dlopen([togglePath UTF8String], RTLD_LAZY);
		if (dylib == NULL) return nil;
		
		is_capable = dlsym(dylib, "isCapable");
		is_enabled = dlsym(dylib, "isEnabled");
		get_state_fast = dlsym(dylib, "getStateFast");
		set_state = dlsym(dylib, "setState");
		get_delay_time = dlsym(dylib, "getDelayTime");
		allow_in_call = dlsym(dylib, "allowInCall");
		invoke_hold_action = dlsym(dylib, "invokeHoldAction");
		close_window = dlsym(dylib, "invokeHoldAction");
		
		if (![self isCapable]) return nil;
	} return self;
}

@end

@interface TDToggleView : UIView {
	TDToggle *toggle;
	UIButton *button;
}

@property (nonatomic, retain) TDToggle *toggle;

@end

@implementation TDToggleView
@synthesize toggle;

- (void)updateIcon {
	[button setImage:[[self toggle] icon] forState:UIControlStateNormal];
}

- (void)cancelTimer {
	[NSObject cancelPreviousPerformRequestsWithTarget:[self toggle]];
}

- (void)togglePressed:(UIButton *)sender {
	[self cancelTimer];
	[[self toggle] setState:![[self toggle] isEnabled]];
	[self updateIcon];
}

- (void)startTimer:(UIButton *)sender {
	[[self toggle] performSelector:@selector(invokeHoldAction) withObject:nil afterDelay:0.75];
}

- (id)initWithToggle:(TDToggle *)t {
	if ((self = [super init])) {
		[self setToggle:t];
		
		CGRect bounds = {{0, 0}, [objc_getClass("SBIcon") defaultIconSize]};
		[self setFrame:bounds];
		
		button = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		[button addTarget:self action:@selector(togglePressed:) forControlEvents:UIControlEventTouchUpInside];
		[button addTarget:self action:@selector(startTimer:) forControlEvents:UIControlEventTouchDown];
		[button addTarget:self action:@selector(cancelTimer) forControlEvents:UIControlEventTouchDragExit];
		[self updateIcon];
		[self addSubview:button];
	} return self;
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	
	[button setFrame:[self bounds]];
}

@end

static NSMutableArray *toggles;

@interface SBAppSwitcherBarView : UIView {
	id _delegate;
	int _orientation;
	NSMutableArray *_appIcons;
	UIView *_contentView;
	UIImageView *_backgroundImage;
	UIView *_auxView;
	id _scrollView;
	UIImageView *_topShadowView;
	UIImageView *_bottomShadowView;
}
- (CGPoint)_firstPageOffset;
- (CGRect)_frameForIndex:(unsigned)index withSize:(CGSize)size;
@end

%hook SBAppSwitcherBarView

- (void)_reflowContent:(BOOL)content {
	%orig;
	
	int index = 0;
	for (TDToggleView *view in toggles) {
		CGRect frame = [self _frameForIndex:index withSize:[objc_getClass("SBIcon") defaultIconSize]];
		frame.size.height = frame.size.width;
		frame.origin.x -= [self _firstPageOffset].x - 320.0f;
		[view setFrame:frame];
		[MSHookIvar<UIScrollView *>(self, "_scrollView") addSubview:view];
		
		index += 1;
	}
	
	CGSize size = [MSHookIvar<UIScrollView *>(self, "_scrollView") contentSize];
	size.width += [self _firstPageOffset].x - 320.0f;
	[MSHookIvar<UIScrollView *>(self, "_scrollView") setContentSize:size];
}

- (CGPoint)_firstPageOffset {
	CGPoint orig = %orig;
	orig.x += 320.0f * ([toggles count] / 4 + 1);
	return orig;
}

%end

%hook SBUIController

- (void)finishLaunching {
	toggles = [[NSMutableArray alloc] initWithCapacity:16];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *files = [manager directoryContentsAtPath:TOGGLE_PATH];

	NSLog(@"starting");

	for (NSString *file in files) {
		NSString *name = file;
		NSString *path = [TOGGLE_PATH stringByAppendingString:file];
		
		NSLog(@"going: %@ %@ %@ %@", files, file, path, name);
		
		TDToggle *toggle = [[TDToggle alloc] initWithName:name path:path];
		if (toggle != nil) {
			TDToggleView *view = [[TDToggleView alloc] initWithToggle:toggle];
			[toggles addObject:view];
		}
	}
	
	NSLog(@"finished");
	
	// XXX: arrange toggles
}

%end


__attribute__((constructor)) static void togglodyte_init() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	
	[pool release];	
}
