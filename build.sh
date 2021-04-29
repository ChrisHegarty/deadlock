set -x
export JAVA_HOME=/Users/chegar/binaries/jdk-11.0.11.jdk/Contents/Home

rm -rf out libbar.dylib teststore

$JAVA_HOME/bin/javac -d out/classes/bar src/classes/r/Bar.java
$JAVA_HOME/bin/javac -d out/classes/foo src/classes/q/Foo.java src/classes/q/FooPrime.java
$JAVA_HOME/bin/javac -d out/classes/main -cp out/classes/bar:out/classes/foo src/classes/p/Main.java

$JAVA_HOME/bin/jar --create --file out/bar.jar  -C out/classes/bar  r/Bar.class
$JAVA_HOME/bin/jar --create --file out/foo.jar  -C out/classes/foo  q/Foo.class -C out/classes/foo q/FooPrime.class
$JAVA_HOME/bin/jar --create --file out/main.jar -C out/classes/main p/Main.class

# compile libbar
gcc -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin/" -o libbar.dylib -shared src/native/libbar/bar.c

# gen self-signed cert and sign foo.jar

$JAVA_HOME/bin/keytool -genkey -noprompt \
 -alias testKey \
 -dname "CN=chegar, OU=JPG, O=JPG, L=Dublin, ST=Ireland, C=IE" \
 -keyalg RSA \
 -keystore teststore \
 -storepass changeit \
 -validity 360
$JAVA_HOME/bin/jarsigner -keystore teststore -storepass changeit out/foo.jar testKey
