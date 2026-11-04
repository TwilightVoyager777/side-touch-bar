// Streams Now Playing information as JSON lines on stdout.
//
// Since macOS 15.4, MediaRemote only returns Now Playing information to
// Apple-signed processes, so the app runs this library inside /usr/bin/perl:
//
//   /usr/bin/perl -e '<DynaLoader script>' libNowPlayingHelper.dylib
//
// Sending commands (play/pause, seek) still works directly from the app.
// The helper exits when stdin closes, i.e. when the app quits.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <unistd.h>

typedef void (*GetInfoFunction)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetIsPlayingFunction)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetPIDFunction)(dispatch_queue_t, void (^)(int));
typedef void (*GetClientFunction)(dispatch_queue_t, void (^)(id));
typedef NSString *(*ClientStringFunction)(id);
typedef void (*RegisterFunction)(dispatch_queue_t);

static GetInfoFunction getInfo;
static GetIsPlayingFunction getIsPlaying;
static GetPIDFunction getPID;
static GetClientFunction getClient;
static ClientStringFunction clientBundleID;
static ClientStringFunction clientParentBundleID;
static NSString *lastLine;

static void put(NSMutableDictionary *dict, NSString *key, id value) {
    if (value) dict[key] = value;
}

static void emit(void) {
    __block NSDictionary *info = nil;
    __block BOOL playing = NO;
    __block int pid = 0;
    __block NSString *bundle = nil;
    __block NSString *parentBundle = nil;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_main_queue();

    dispatch_group_enter(group);
    getInfo(queue, ^(NSDictionary *value) { info = value; dispatch_group_leave(group); });
    if (getIsPlaying) {
        dispatch_group_enter(group);
        getIsPlaying(queue, ^(Boolean value) { playing = value; dispatch_group_leave(group); });
    }
    if (getPID) {
        dispatch_group_enter(group);
        getPID(queue, ^(int value) { pid = value; dispatch_group_leave(group); });
    }
    if (getClient) {
        dispatch_group_enter(group);
        getClient(queue, ^(id client) {
            if (client && clientBundleID) bundle = clientBundleID(client);
            if (client && clientParentBundleID) parentBundle = clientParentBundleID(client);
            dispatch_group_leave(group);
        });
    }

    dispatch_group_notify(group, queue, ^{
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
        out[@"active"] = @(title.length > 0);
        if (title.length > 0) {
            put(out, @"title", title);
            put(out, @"artist", info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
            put(out, @"album", info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);
            put(out, @"duration", info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
            put(out, @"elapsed", info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
            put(out, @"rate", info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
            NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
            if ([timestamp isKindOfClass:[NSDate class]]) out[@"timestamp"] = @(timestamp.timeIntervalSince1970);
            out[@"playing"] = @(playing);
            if (pid > 0) out[@"pid"] = @(pid);
            put(out, @"bundle", bundle);
            put(out, @"parentBundle", parentBundle);
        }

        NSData *data = [NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingSortedKeys error:nil];
        if (!data) return;
        NSString *line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([line isEqualToString:lastLine]) return;
        lastLine = line;
        printf("%s\n", line.UTF8String);
        fflush(stdout);
    });
}

static void observe(void *handle, const char *symbol) {
    NSString *__unsafe_unretained *name = (NSString *__unsafe_unretained *)dlsym(handle, symbol);
    NSString *notification = name ? *name : [NSString stringWithUTF8String:symbol];
    [[NSNotificationCenter defaultCenter] addObserverForName:notification object:nil queue:nil usingBlock:^(NSNotification *note) {
        emit();
    }];
}

void stb_stream(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (!handle) exit(1);

    getInfo = (GetInfoFunction)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    getIsPlaying = (GetIsPlayingFunction)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    getPID = (GetPIDFunction)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID");
    getClient = (GetClientFunction)dlsym(handle, "MRMediaRemoteGetNowPlayingClient");
    clientBundleID = (ClientStringFunction)dlsym(handle, "MRNowPlayingClientGetBundleIdentifier");
    clientParentBundleID = (ClientStringFunction)dlsym(handle, "MRNowPlayingClientGetParentAppBundleIdentifier");
    RegisterFunction registerForNotifications = (RegisterFunction)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (!getInfo) exit(1);

    if (registerForNotifications) registerForNotifications(dispatch_get_main_queue());
    observe(handle, "kMRMediaRemoteNowPlayingInfoDidChangeNotification");
    observe(handle, "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification");
    observe(handle, "kMRMediaRemoteNowPlayingApplicationDidChangeNotification");

    // Some players don't post changes on seek; refresh periodically as well.
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) { emit(); }];

    // Quit with the app: the app holds our stdin open.
    [NSThread detachNewThreadWithBlock:^{
        char buffer[256];
        while (read(STDIN_FILENO, buffer, sizeof buffer) > 0) {}
        exit(0);
    }];

    emit();
    CFRunLoopRun();
}
