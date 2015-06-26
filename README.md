# Avowal
Futures and Promises for modern CFML, inspired by my earlier cfconcurrency library.

Unlike cfconcurrency, which relied on the Asynchronous CFML Gateway and CFCs for everything, Avowal relies on `thread` internally and closures, so it requires Railo 4, Lucee, or Adobe ColdFusion 10+.

The basic intent behind this library is to provide a simple, fluid interface for creating future values and for orchestrating sequences of those through completable futures (promises).

## Basic Usage

You can create a `future` and pass it either a function / closure to be executed in another thread, or you can pass a CFC instance that has at least a `call()` method to be executed in another thread.

    var f = new avowal.future( function() {
        var v = someLongProcess(); return computeResult( v );
    } );
    // continue on with other work
    ...
    // pick up the value
    doSomethingWith( f.get() );

This will return the result immediately if it has already completed, otherwise it will wait for the future to complete.

If you want a cancellable future, you need a CFC instance that has both a `call()` method, for the main process, and a `stop()` method which the future will attempt to call if asked to cancel a running thread. If `stop()` is called, it is passed the the future value itself, and should called `stopped()` on the future to indicate it successfully cancelled the task.

Here is `process.cfc`:

    component {
        function call() {
            // some big complex process
            // occasionally checks cancel to see if it should stop
            if ( structKeyExists( variables, "cancel" ) ) {
                // cancel is the future we need to tell that we stopped
                variables.cancel.stopped();
                return;
            }
            // more complex stuff
            return result;
        }
        function stop( future ) {
            // set this as a flag to ask the process to interrupt
            variables.cancel = future;
        }
    }

Here's the main code:

    var f = new avowal.future( new process() );
    // continue on with stuff
    ...
    // decide to try to stop the future
    f.cancel();

Instead of a CFC instance, you can also pass a struct with function/closure members `call` (and `stop` if you want it to be cancellable).

By default, the task starts immediately when the future is created. If you pass a CFC (or struct), you can prevent this by having either a public field `autorun` set to `false` or a public method `autorun()` that returns `false`. You must then call `run()` yourself.

    var f = new avowal.future( { call : function() { doSlowStuff(); }, autorun : false } );
    // maybe some other setup stuff
    ...
    // start the future
    f.run();

_More details coming soon._

# License

Copyright (c) 2015 Sean Corfield

Distributed under the Apache Software License 2.0.
