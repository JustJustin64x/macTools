#import <Foundation/Foundation.h>

int main(void) {
    @autoreleasepool {
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/macTools.app"];
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
        task.arguments = @[path];
        NSError *error = nil;
        if (![task launchAndReturnError:&error]) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        [task waitUntilExit];
        return task.terminationStatus;
    }
}
