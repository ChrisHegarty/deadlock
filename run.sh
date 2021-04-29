set -x
export JAVA_HOME=/Users/chegar/binaries/jdk-11.0.11.jdk/Contents/Home

$JAVA_HOME/bin/java -cp out/main.jar:out/bar.jar:out/foo.jar p.Main
