A minimal testcase that demonstrates a deadlock when loading a native library on one thread, while simultaneously attempting to load a class from a signed jar on
another thread.

##### Compiles, builds, signs, etc three jar files, main.jar, bar.jar, foo.jar:

    bash build.sh

##### Runs the program (note the order of jars on the class path)

    bash run.sh

    $JAVA_HOME/bin/java -cp out/main.jar:out/bar.jar:out/foo.jar p.Main

#### Outline of the test:

* The `Foo` and `FooPrime` classes themselves are uninteresting. What is interesting is that they live in the **signed** foo.jar. The sole purpose of the `Foo` and `FooPrime` classes is to have two different types that can be loadable from a signed jar on the class path (other than that of the other test classes/jars).

* The `Bar` class contains a class initializer which loads the native _libbar_ library. It lives in bar.jar The `JNI_OnLoad` of _libbar_ tries to find/load the `FooPrime` class.

* The `Main` class lives in main.jar and is the orchestrator. The `Main::main` entry point method starts a race (on foo.jar); one thread, `Thread-A`, loading the `FooPrime` class transitively through the initialization of the `Bar` class, and another thread, `Thread-B`, loading the `Foo` class directly.

The class path is a list of archives (and directories) that are searched sequentially by the application classloader, i.e. order is significant. In this particular case, bar.jar is **before** foo.jar - which is large part of the issue.

#### The deadlock occurs in the classloader when:

1. Thread A tries to lock the monitor on the backing `JarFile` for foo.jar, while holding the monitor for the JVM-wide `Runtime` object, while

2. Thread B tries to lock the monitor for the JVM-wide `Runtime` object, while holding the monitor on the backing `JarFile` for foo.jar.

We know why Thread-A is doing what it is doing (since that is clear from the test code), but Thread-B is a little more mysterious. Thread-B is verifying the signature of the signed jar file foo.jar. To do this, Thread-B triggers the initialization of the JCE framework, which in turn fires up service-loader to search the JDK's installed providers. This search can result in an attempt to load a native library (associated with the provider implementation itself, like say SunEC, or just some other implementation detail of the classloader ).

#### Source layout

    $ tree src
    src
    ├── classes
    │   ├── p
    │   │   └── Main.java
    │   ├── q
    │   │   ├── Foo.java
    │   │   └── FooPrime.java
    │   └── r
    │       └── Bar.java
    └── native
        └── libbar
            └── bar.c

6 directories, 5 files


Compiles into three jar files. foo.jar is signed:

    $ ls -la out
    ...
    -rw-r--r--   1 chhegar  staff   757 29 Apr 17:00 bar.jar
    drwxr-xr-x   5 chhegar  staff   160 29 Apr 17:00 classes
    -rw-r--r--   1 chhegar  staff  2281 29 Apr 17:00 foo.jar    ## << signed
    -rw-r--r--   1 chhegar  staff  1284 29 Apr 17:00 main.jar    

Example output

    $ bash run.sh
    + export JAVA_HOME=/Users/chegar/binaries/jdk-11.0.11.jdk/Contents/Home
    + JAVA_HOME=/Users/chegar/binaries/jdk-11.0.11.jdk/Contents/Home
    + /Users/chegar/binaries/jdk-11.0.11.jdk/Contents/Home/bin/java -cp out/main.jar:out/bar.jar:out/foo.jar p.Main
    ^\2021-04-29 17:34:10
    Full thread dump Java HotSpot(TM) 64-Bit Server VM (11.0.11+9-LTS-194 mixed mode):

    ...

    Found one Java-level deadlock:
    =============================
    "Thread-A":
      waiting to lock monitor 0x0000000100df1f00 (object 0x000000070fe90460, a java.util.jar.JarFile),
      which is held by "Thread-B"
    "Thread-B":
      waiting to lock monitor 0x0000000100df0000 (object 0x000000070ff07b28, a java.lang.Runtime),
      which is held by "Thread-A"

    Java stack information for the threads listed above:
    ===================================================
    "Thread-A":
    	at java.util.zip.ZipFile.getEntry(java.base@11.0.11/ZipFile.java:347)
    	- waiting to lock <0x000000070fe90460> (a java.util.jar.JarFile)
    	at java.util.zip.ZipFile$1.getEntry(java.base@11.0.11/ZipFile.java:1118)
    	at java.util.jar.JarFile.getEntry0(java.base@11.0.11/JarFile.java:578)
    	at java.util.jar.JarFile.getEntry(java.base@11.0.11/JarFile.java:508)
    	at java.util.jar.JarFile.getJarEntry(java.base@11.0.11/JarFile.java:470)
    	at jdk.internal.loader.URLClassPath$JarLoader.getResource(java.base@11.0.11/URLClassPath.java:931)
    	at jdk.internal.loader.URLClassPath.getResource(java.base@11.0.11/URLClassPath.java:314)
    	at jdk.internal.loader.BuiltinClassLoader.findClassOnClassPathOrNull(java.base@11.0.11/BuiltinClassLoader.java:695)
    	at jdk.internal.loader.BuiltinClassLoader.loadClassOrNull(java.base@11.0.11/BuiltinClassLoader.java:621)
    	- locked <0x000000070fe4dc60> (a java.lang.Object)
    	at jdk.internal.loader.BuiltinClassLoader.loadClass(java.base@11.0.11/BuiltinClassLoader.java:579)
    	at jdk.internal.loader.ClassLoaders$AppClassLoader.loadClass(java.base@11.0.11/ClassLoaders.java:178)
    	at java.lang.ClassLoader.loadClass(java.base@11.0.11/ClassLoader.java:521)
    	at java.lang.ClassLoader$NativeLibrary.load0(java.base@11.0.11/Native Method)
    	at java.lang.ClassLoader$NativeLibrary.load(java.base@11.0.11/ClassLoader.java:2430)
    	at java.lang.ClassLoader$NativeLibrary.loadLibrary(java.base@11.0.11/ClassLoader.java:2487)
    	- locked <0x000000070ff076c8> (a java.util.HashSet)
    	at java.lang.ClassLoader.loadLibrary0(java.base@11.0.11/ClassLoader.java:2684)
    	at java.lang.ClassLoader.loadLibrary(java.base@11.0.11/ClassLoader.java:2617)
    	at java.lang.Runtime.load0(java.base@11.0.11/Runtime.java:765)
    	- locked <0x000000070ff07b28> (a java.lang.Runtime)
    	at java.lang.System.load(java.base@11.0.11/System.java:1835)
    	at r.Bar.<clinit>(Bar.java:11)
    	at p.Main.lambda$main$0(Main.java:8)
    	at p.Main$$Lambda$1/0x0000000800067040.run(Unknown Source)
    	at java.lang.Thread.run(java.base@11.0.11/Thread.java:834)
    "Thread-B":
    	at java.lang.Runtime.loadLibrary0(java.base@11.0.11/Runtime.java:819)
    	- waiting to lock <0x000000070ff07b28> (a java.lang.Runtime)
    	at java.lang.System.loadLibrary(java.base@11.0.11/System.java:1871)
    	at jdk.internal.jimage.NativeImageBuffer$1.run(java.base@11.0.11/NativeImageBuffer.java:41)
    	at jdk.internal.jimage.NativeImageBuffer$1.run(java.base@11.0.11/NativeImageBuffer.java:39)
    	at java.security.AccessController.doPrivileged(java.base@11.0.11/Native Method)
    	at jdk.internal.jimage.NativeImageBuffer.<clinit>(java.base@11.0.11/NativeImageBuffer.java:38)
    	at jdk.internal.jimage.BasicImageReader.<init>(java.base@11.0.11/BasicImageReader.java:95)
    	at jdk.internal.jimage.ImageReader$SharedImageReader.<init>(java.base@11.0.11/ImageReader.java:224)
    	at jdk.internal.jimage.ImageReader$SharedImageReader.open(java.base@11.0.11/ImageReader.java:238)
    	- locked <0x000000070fd53a30> (a java.util.HashMap)
    	at jdk.internal.jimage.ImageReader.open(java.base@11.0.11/ImageReader.java:67)
    	at jdk.internal.jimage.ImageReader.open(java.base@11.0.11/ImageReader.java:71)
    	at jdk.internal.jimage.ImageReaderFactory$1.apply(java.base@11.0.11/ImageReaderFactory.java:70)
    	at jdk.internal.jimage.ImageReaderFactory$1.apply(java.base@11.0.11/ImageReaderFactory.java:67)
    	at java.util.concurrent.ConcurrentHashMap.computeIfAbsent(java.base@11.0.11/ConcurrentHashMap.java:1705)
    	- locked <0x000000070fd53520> (a java.util.concurrent.ConcurrentHashMap$ReservationNode)
    	at jdk.internal.jimage.ImageReaderFactory.get(java.base@11.0.11/ImageReaderFactory.java:61)
    	at jdk.internal.jimage.ImageReaderFactory.getImageReader(java.base@11.0.11/ImageReaderFactory.java:85)
    	at jdk.internal.module.SystemModuleFinders$SystemImage.<clinit>(java.base@11.0.11/SystemModuleFinders.java:383)
    	at jdk.internal.module.SystemModuleFinders$SystemModuleReader.findImageLocation(java.base@11.0.11/SystemModuleFinders.java:426)
    	at jdk.internal.module.SystemModuleFinders$SystemModuleReader.read(java.base@11.0.11/SystemModuleFinders.java:464)
    	at jdk.internal.loader.BuiltinClassLoader.defineClass(java.base@11.0.11/BuiltinClassLoader.java:747)
    	at jdk.internal.loader.BuiltinClassLoader.findClassInModuleOrNull(java.base@11.0.11/BuiltinClassLoader.java:680)
    	at jdk.internal.loader.BuiltinClassLoader.findClass(java.base@11.0.11/BuiltinClassLoader.java:561)
    	at java.lang.ClassLoader.loadClass(java.base@11.0.11/ClassLoader.java:633)
    	- locked <0x000000070fd529d8> (a java.lang.Object)
    	at java.lang.Class.forName(java.base@11.0.11/Class.java:474)
    	at java.util.ServiceLoader.loadProvider(java.base@11.0.11/ServiceLoader.java:852)
    	at java.util.ServiceLoader$ModuleServicesLookupIterator.hasNext(java.base@11.0.11/ServiceLoader.java:1077)
    	at java.util.ServiceLoader$2.hasNext(java.base@11.0.11/ServiceLoader.java:1300)
    	at java.util.ServiceLoader$3.hasNext(java.base@11.0.11/ServiceLoader.java:1385)
    	at sun.security.jca.ProviderConfig$ProviderLoader.load(java.base@11.0.11/ProviderConfig.java:334)
    	at sun.security.jca.ProviderConfig$3.run(java.base@11.0.11/ProviderConfig.java:244)
    	at sun.security.jca.ProviderConfig$3.run(java.base@11.0.11/ProviderConfig.java:238)
    	at java.security.AccessController.doPrivileged(java.base@11.0.11/Native Method)
    	at sun.security.jca.ProviderConfig.doLoadProvider(java.base@11.0.11/ProviderConfig.java:238)
    	at sun.security.jca.ProviderConfig.getProvider(java.base@11.0.11/ProviderConfig.java:218)
    	- locked <0x000000070fea7388> (a sun.security.jca.ProviderConfig)
    	at sun.security.jca.ProviderList.loadAll(java.base@11.0.11/ProviderList.java:315)
    	at sun.security.jca.ProviderList.removeInvalid(java.base@11.0.11/ProviderList.java:332)
    	at sun.security.jca.Providers.getFullProviderList(java.base@11.0.11/Providers.java:165)
    	- locked <0x000000070fe9b980> (a java.lang.Class for sun.security.jca.Providers)
    	at java.security.Security.getProviders(java.base@11.0.11/Security.java:457)
    	at sun.security.x509.AlgorithmId.computeOidTable(java.base@11.0.11/AlgorithmId.java:632)
    	at sun.security.x509.AlgorithmId.oidTable(java.base@11.0.11/AlgorithmId.java:622)
    	- locked <0x000000070fec9478> (a java.lang.Class for sun.security.x509.AlgorithmId)
    	at sun.security.x509.AlgorithmId.algOID(java.base@11.0.11/AlgorithmId.java:604)
    	at sun.security.x509.AlgorithmId.get(java.base@11.0.11/AlgorithmId.java:436)
    	at sun.security.pkcs.SignerInfo.verify(java.base@11.0.11/SignerInfo.java:379)
    	at sun.security.pkcs.PKCS7.verify(java.base@11.0.11/PKCS7.java:578)
    	at sun.security.pkcs.PKCS7.verify(java.base@11.0.11/PKCS7.java:595)
    	at sun.security.util.SignatureFileVerifier.processImpl(java.base@11.0.11/SignatureFileVerifier.java:283)
    	at sun.security.util.SignatureFileVerifier.process(java.base@11.0.11/SignatureFileVerifier.java:259)
    	at java.util.jar.JarVerifier.processEntry(java.base@11.0.11/JarVerifier.java:316)
    	at java.util.jar.JarVerifier.update(java.base@11.0.11/JarVerifier.java:230)
    	at java.util.jar.JarFile.initializeVerifier(java.base@11.0.11/JarFile.java:759)
    	at java.util.jar.JarFile.ensureInitialization(java.base@11.0.11/JarFile.java:1038)
    	- locked <0x000000070fe90460> (a java.util.jar.JarFile)
    	at java.util.jar.JavaUtilJarAccessImpl.ensureInitialization(java.base@11.0.11/JavaUtilJarAccessImpl.java:69)
    	at jdk.internal.loader.URLClassPath$JarLoader$2.getManifest(java.base@11.0.11/URLClassPath.java:872)
    	at jdk.internal.loader.BuiltinClassLoader.defineClass(java.base@11.0.11/BuiltinClassLoader.java:786)
    	at jdk.internal.loader.BuiltinClassLoader.findClassOnClassPathOrNull(java.base@11.0.11/BuiltinClassLoader.java:698)
    	at jdk.internal.loader.BuiltinClassLoader.loadClassOrNull(java.base@11.0.11/BuiltinClassLoader.java:621)
    	- locked <0x000000070fe8fe58> (a java.lang.Object)
    	at jdk.internal.loader.BuiltinClassLoader.loadClass(java.base@11.0.11/BuiltinClassLoader.java:579)
    	at jdk.internal.loader.ClassLoaders$AppClassLoader.loadClass(java.base@11.0.11/ClassLoaders.java:178)
    	at java.lang.ClassLoader.loadClass(java.base@11.0.11/ClassLoader.java:521)
    	at p.Main.lambda$main$1(Main.java:14)
    	at p.Main$$Lambda$2/0x0000000800066840.run(Unknown Source)
    	at java.lang.Thread.run(java.base@11.0.11/Thread.java:834)

    Found 1 deadlock.
