#import <AppKit/AppKit.h>

@interface MacToolsLauncherDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MacToolsLauncherDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/macTools.app"];
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:[NSURL fileURLWithPath:path]
                                        configuration:configuration
                                    completionHandler:^(NSRunningApplication *application, NSError *error) {
        (void)application;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"macTools konnte nicht geöffnet werden.";
                alert.informativeText = error.localizedDescription;
                [alert runModal];
            }
            [NSApp terminate:nil];
        });
    }];
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        MacToolsLauncherDelegate *delegate = [[MacToolsLauncherDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application run];
    }
    return 0;
}
