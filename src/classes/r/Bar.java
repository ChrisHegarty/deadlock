package r;

import java.io.File;

public class Bar {

    static final String LIB_PREFIX = "lib";
    static final String LIB_suffix = ".dylib";

    static {
        System.load((new File(LIB_PREFIX + "bar" + LIB_suffix)).getAbsolutePath());
        System.out.println("libbar loaded");
    }
}
