// mobileso builds vrgram daemon as a C shared library for Android.
// Build with:
//
//	GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
//	  CC=<ndk>/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang \
//	  go build -buildmode=c-shared -ldflags=-checklinkname=0 \
//	  -o ../flutter/android/app/src/main/jniLibs/arm64-v8a/libvrgram.so ./mobileso/
package main

/*
#include <jni.h>
#include <stdlib.h>

static const char* jstringToChars(JNIEnv* env, jstring js) {
	if (js == NULL) return "";
	return (*env)->GetStringUTFChars(env, js, NULL);
}

static void releaseChars(JNIEnv* env, jstring js, const char* cStr) {
	if (js != NULL && cStr != NULL) {
		(*env)->ReleaseStringUTFChars(env, js, cStr);
	}
}
*/
import "C"

import (
	"fmt"

	"github.com/user/dns-transport/mobile"
)

//export Java_com_example_vrgram_GoBridge_startDaemon
func Java_com_example_vrgram_GoBridge_startDaemon(env *C.JNIEnv, clazz C.jclass, grpcPort C.int, relayList C.jstring, zone C.jstring, forceBlackout C.jstring, dataDir C.jstring, p2pPort C.int, bootstrapAddrs C.jstring) {
	fmt.Println("[VRGram-SO] JNI function called")
	rl := jstringToGo(env, relayList)
	z := jstringToGo(env, zone)
	fb := jstringToGo(env, forceBlackout)
	dd := jstringToGo(env, dataDir)
	ba := jstringToGo(env, bootstrapAddrs)

	fmt.Printf("[VRGram-SO] grpcPort=%d dataDir=%s p2pPort=%d\n", int(grpcPort), dd.str, int(p2pPort))

	mobile.StartDaemon(
		int(grpcPort),
		rl.str,
		z.str,
		fb.str,
		dd.str,
		int(p2pPort),
		ba.str,
	)

	// Release all after StartDaemon returns (it spawns its own goroutine,
	// but the jstring pointers are only needed for the duration of the call).
	rl.release(env)
	z.release(env)
	fb.release(env)
	dd.release(env)
	ba.release(env)
}

type jstr struct {
	str string
	c   *C.char
	js  C.jstring
}

func jstringToGo(env *C.JNIEnv, js C.jstring) jstr {
	if js == 0 {
		return jstr{}
	}
	cStr := C.jstringToChars(env, js)
	return jstr{str: C.GoString(cStr), c: cStr, js: js}
}

func (j jstr) release(env *C.JNIEnv) {
	C.releaseChars(env, j.js, j.c)
}

func main() {}
