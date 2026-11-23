#include "FinderKeys.h"
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

static CFMachPortRef eventTap;
static bool verbose;
typedef enum { Unchanged, Open, Rename } Mapping;
static Mapping held[128];

static bool is_finder_file_list_active(void) {
    @autoreleasepool {
    AXUIElementRef app = NULL, focus = NULL;
    bool result = false;
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (verbose) fprintf(stderr, "Aktive Anwendung: %s\n", front.bundleIdentifier.UTF8String ?: "unbekannt");
    if (![front.bundleIdentifier isEqualToString:@"com.apple.finder"])
        goto done;
    app = AXUIElementCreateApplication(front.processIdentifier);
    AXUIElementSetMessagingTimeout(app, 0.15);
    // Fail closed: never convert Enter if Finder cannot report the focused control.
    AXError error = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute, (CFTypeRef *)&focus);
    if (error != kAXErrorSuccess || !focus) {
        if (verbose) fprintf(stderr, "Finder-Fokus nicht lesbar (AX %d).\n", error);
        goto done;
    }
    CFTypeRef role = NULL;
    if (AXUIElementCopyAttributeValue(focus, kAXRoleAttribute, &role) == kAXErrorSuccess && role) {
        if (CFGetTypeID(role) == CFStringGetTypeID()) {
            char roleName[128] = "?";
            CFStringGetCString(role, roleName, sizeof(roleName), kCFStringEncodingUTF8);
            if (verbose) fprintf(stderr, "Finder-Fokusrolle: %s\n", roleName);
            result = !CFEqual(role, kAXTextFieldRole) && !CFEqual(role, kAXTextAreaRole) &&
                     !CFEqual(role, CFSTR("AXSearchField")) &&
                     !CFEqual(role, CFSTR("AXComboBox"));
        }
        CFRelease(role);
    }
done:
    if (focus) CFRelease(focus);
    if (app) CFRelease(app);
    return result;
    }
}

static Mapping choose_mapping(CGKeyCode key, CGEventFlags flags, bool finder) {
    CGEventFlags modifiers = kCGEventFlagMaskCommand | kCGEventFlagMaskControl |
                            kCGEventFlagMaskAlternate | kCGEventFlagMaskShift;
    if (!finder || (flags & modifiers)) return Unchanged;
    if (key == kVK_Return || key == kVK_ANSI_KeypadEnter) return Open;
    if (key == kVK_F2) return Rename;
    return Unchanged;
}

static void apply_mapping(CGEventRef event, Mapping mapping) {
    if (mapping == Unchanged) return;
    CGEventFlags flags = CGEventGetFlags(event);
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode,
                               mapping == Open ? kVK_ANSI_O : kVK_Return);
    flags &= ~kCGEventFlagMaskSecondaryFn;
    if (mapping == Open) flags |= kCGEventFlagMaskCommand;
    CGEventSetFlags(event, flags);
}

static CGEventRef event_callback(CGEventTapProxy proxy, CGEventType type,
                                 CGEventRef event, void *refcon) {
    (void)proxy; (void)refcon;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        memset(held, 0, sizeof(held));
        if (eventTap) CGEventTapEnable(eventTap, true);
        if (verbose) fprintf(stderr, "Tastaturfilter erneut aktiviert.\n");
        return event;
    }
    if (type != kCGEventKeyDown && type != kCGEventKeyUp) return event;
    CGKeyCode key = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    if (key != kVK_Return && key != kVK_ANSI_KeypadEnter && key != kVK_F2) return event;
    Mapping mapping = held[key];
    if (type == kCGEventKeyDown) {
        if (!CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat)) {
            mapping = choose_mapping(key, CGEventGetFlags(event), is_finder_file_list_active());
            held[key] = mapping;
            if (verbose) fprintf(stderr, "Taste %u: %s\n", key,
                                 mapping == Open ? "Öffnen" : mapping == Rename ? "Umbenennen" : "unverändert");
        }
    } else {
        // Reuse key-down decision even if opening changed the active app or focus.
        held[key] = Unchanged;
    }
    if (mapping == Unchanged) return event;
    // Build a fresh keyboard event rather than retaining Return's cached text
    // and platform-specific payload when changing it to a shortcut.
    CGEventRef replacement = CGEventCreateKeyboardEvent(NULL,
        mapping == Open ? kVK_ANSI_O : kVK_Return, type == kCGEventKeyDown);
    if (!replacement) return event;
    CGEventSetFlags(replacement, CGEventGetFlags(event));
    CGEventSetTimestamp(replacement, CGEventGetTimestamp(event));
    CGEventSetIntegerValueField(replacement, kCGKeyboardEventAutorepeat,
                               CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat));
    apply_mapping(replacement, mapping);
    // Core Graphics owns and releases a replacement returned by the callback.
    return replacement;
}

static CGEventMask event_mask(void) {
    return CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
}

static int check_permissions(bool prompt) {
    const void *keys[] = {kAXTrustedCheckOptionPrompt};
    const void *values[] = {prompt ? kCFBooleanTrue : kCFBooleanFalse};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    bool trusted = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);
    fprintf(stderr, "Bedienungshilfen: %s\n", trusted ? "freigegeben" : "NICHT freigegeben");
    if (!trusted) {
        fprintf(stderr, "Systemeinstellungen > Datenschutz & Sicherheit > Bedienungshilfen:\n"
                        "macTools.app über + hinzufügen und aktivieren, anschließend das Tool neu starten.\n"
                        "Bei Start aus einem Terminal dessen Freigabe ebenfalls prüfen.\n");
        return 1;
    }
    return 0;
}

int finder_keys_self_test(void) {
#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "Test fehlgeschlagen: %s\n", #condition); return 1; } } while (0)
    CHECK(choose_mapping(kVK_Return, 0, true) == Open);
    CHECK(choose_mapping(kVK_ANSI_KeypadEnter, kCGEventFlagMaskNumericPad, true) == Open);
    CHECK(choose_mapping(kVK_F2, kCGEventFlagMaskSecondaryFn, true) == Rename);
    CHECK(choose_mapping(kVK_Return, 0, false) == Unchanged);
    CGEventFlags modifiers[] = {kCGEventFlagMaskCommand, kCGEventFlagMaskControl,
                               kCGEventFlagMaskAlternate, kCGEventFlagMaskShift};
    for (size_t i = 0; i < sizeof(modifiers) / sizeof(modifiers[0]); i++)
        CHECK(choose_mapping(kVK_Return, modifiers[i], true) == Unchanged);
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, kVK_Return, true);
    CHECK(event != NULL);
    apply_mapping(event, Open);
    CHECK(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == kVK_ANSI_O);
    CHECK(CGEventGetFlags(event) & kCGEventFlagMaskCommand);
    CFRelease(event);
    held[kVK_Return] = Open;
    event = CGEventCreateKeyboardEvent(NULL, kVK_Return, false);
    CGEventRef replacement = event_callback(NULL, kCGEventKeyUp, event, NULL);
    CHECK(replacement != event);
    CHECK(CGEventGetIntegerValueField(replacement, kCGKeyboardEventKeycode) == kVK_ANSI_O);
    CHECK(held[kVK_Return] == Unchanged);
    CFRelease(replacement);
    CFRelease(event);
    held[kVK_F2] = Rename;
    event = CGEventCreateKeyboardEvent(NULL, kVK_F2, false);
    CGEventSetFlags(event, kCGEventFlagMaskSecondaryFn);
    replacement = event_callback(NULL, kCGEventKeyUp, event, NULL);
    CHECK(CGEventGetIntegerValueField(replacement, kCGKeyboardEventKeycode) == kVK_Return);
    CHECK(!(CGEventGetFlags(replacement) & kCGEventFlagMaskSecondaryFn));
    CHECK(held[kVK_F2] == Unchanged);
    CFRelease(replacement);
    CFRelease(event);
    puts("Selbsttest erfolgreich: Enter, Ziffernblock, F2, Modifikatoren und Loslassen.");
    return 0;
}

int finder_keys_run(bool verbose_logging, bool check) {
    verbose = verbose_logging;
    if (check_permissions(!check)) return 1;
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault, event_mask(), event_callback, NULL);
    if (!eventTap) {
        fprintf(stderr, "Tastaturfilter konnte nicht erstellt werden. Freigabe und Eingabeüberwachung prüfen.\n");
        return 1;
    }
    if (check) {
        puts("Tastaturfilter: verfügbar.");
        if (verbose) fprintf(stderr, "Finder-Dateiliste aktiv: %s\n", is_finder_file_list_active() ? "ja" : "nein");
        CFRelease(eventTap);
        return 0;
    }
    CFMachPortRef tap = eventTap;
    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
    if (!source) { CFRelease(tap); return 1; }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    puts("Finder Enter läuft (Enter = Öffnen, F2 bzw. fn+F2 = Umbenennen).");
    fflush(stdout);
    CFRunLoopRun();
    CFRelease(source);
    CFRelease(tap);
    return 0;
}
