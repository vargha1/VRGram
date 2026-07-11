// mobileso builds vrgram daemon as a C shared library for Android.
// Build with:
//
//	GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
//	  CC=<ndk>/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang \
//	  go build -buildmode=c-shared -ldflags="-s -w -checklinkname=0" \
//	  -o ../flutter/android/app/src/main/jniLibs/arm64-v8a/libvrgram.so ./mobileso/
package main

/*
#include <jni.h>
#include <stdlib.h>
#include <string.h>

// Convert Java jstring to C string and return allocated C string.
// Caller must free the returned string.
static char* jstringToCString(JNIEnv* env, jstring js) {
    if (js == NULL) return strdup("");
    const char* cStr = (*env)->GetStringUTFChars(env, js, NULL);
    if (cStr == NULL) return strdup("");
    char* result = strdup(cStr);
    (*env)->ReleaseStringUTFChars(env, js, cStr);
    return result;
}
*/
import "C"

import (
	"fmt"

	"github.com/user/dns-transport/mobile"
)

//export Java_com_example_vrgram_GoBridge_startDaemon
func Java_com_example_vrgram_GoBridge_startDaemon(env *C.JNIEnv, clazz C.jclass, grpcPort C.int, relayList C.jstring, zone C.jstring, forceBlackout C.jstring, dataDir C.jstring, p2pPort C.int, bootstrapAddrs C.jstring, dnsResolver C.jstring) {
	fmt.Println("[VRGram-SO] JNI function called")

	// Convert all jstrings to Go strings in C code (properly releasing JNI refs)
	rl := C.GoString(C.jstringToCString(env, relayList))
	z := C.GoString(C.jstringToCString(env, zone))
	fb := C.GoString(C.jstringToCString(env, forceBlackout))
	dd := C.GoString(C.jstringToCString(env, dataDir))
	dr := C.GoString(C.jstringToCString(env, dnsResolver))

	fmt.Printf("[VRGram-SO] grpcPort=%d dataDir=%s dnsResolver=%s\n", int(grpcPort), dd, dr)

	mobile.StartDaemon(
		int(grpcPort),
		rl,
		z,
		fb,
		dd,
		dr,
	)
}

func main() {}
