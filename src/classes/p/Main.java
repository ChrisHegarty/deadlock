package p ;

public class Main {

    public static void main(String... args) throws Exception {

        Runnable r1 = () -> {
            var bar = new r.Bar();  // loaded from b.jar, which triggers a loadLibrary
            System.out.println(Thread.currentThread().getName() + ": bar=" + bar);
        };
        Thread t1 = new Thread(r1, "Thread-A");

        Runnable r2 = () -> {
            var foo = new q.Foo();  // loaded from foo.jar, which is signed
            System.out.println(Thread.currentThread().getName() + ": foo=" + foo);
        };
        Thread t2 = new Thread(r2, "Thread-B");

        t1.start();
        t2.start();
        t1.join();
        t2.join();
    }
}
