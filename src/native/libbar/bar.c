
#include "jni.h"

JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *reserved)
{
    JNIEnv *env;
    jclass iCls;

    if ((*vm)->GetEnv(vm, (void**) &env, JNI_VERSION_1_2) != JNI_OK) {
        return JNI_EVERSION; /* JNI version not supported */
    }

    iCls = (*env)->FindClass(env, "q/FooPrime");  // triggers a load from foo.jar
    fprintf(stdout, "\nHello from libbar OnLoad\n");
    fflush(stdout);

    return JNI_VERSION_1_2;
}
