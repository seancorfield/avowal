component {
/*
    Copyright (c) 2015 Sean A Corfield http://corfield.org/

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
    // SLEEP_UNIT -- default time (ms) that future sleeps between checks
    this.SLEEP_UNIT = 100;

    variables.thread = createObject( "java", "java.lang.Thread" );
    variables.status = "NULL"; // or READY, RUNNING, DONE, FAILED, CANCELLED

    // task is first argument, additional args can be provided
    // task can be a function/closure or a CFC/struct with a call() method
    // tasks that are CFCs/structs with a stop() method are cancellable
    public any function init( required any task ) {
        variables.task = task;
        structDelete( variables, "result" );
        if ( structKeyExists( arguments, 1 ) ) {
            // positional arguments, copy and delete 1st one
            variables.args = [ ];
            for ( var arg in arguments ) {
                arrayAppend( variables.args, arg );
            }
            arrayDeleteAt( variables.args, 1 );
        } else {
            // named arguments, copy and delete task
            variables.args = { };
            structAppend( variables.args, arguments );
            structDelete( variables.args, "task" );
        }
        param name="request._avowal_tid" default="0";
        param name="request._avowal_Q" default="#{ }#";
        var autorun = true;
        if ( isStruct( task ) &&
             structKeyExists( task, "autorun" ) ) {
            if ( isBoolean( task.autorun ) ) {
                autorun = task.autorun;
            } else if ( isCustomFunction( task.autorun ) ||
                        isClosure( task.autorun ) ) {
                autorun = task.autorun();
            }
        }
        variables.status = "READY";
        if ( autorun ) run();
        return this;
    }

    public boolean function cancel( boolean mayInterruptIfRunning = false ) {
        var canceled = false;
        switch ( variables.status ) {
        case "READY":
            canceled = true;
            terminate( "CANCELLED" );
            break;
        case "RUNNING":
            if ( mayInterruptIfRunning ) {
                if ( isStruct( variables.task ) &&
                     structKeyExists( variables.task, "stop" ) &&
                     ( isCustomFunction( variables.task.stop ) ||
                       isClosure( variables.task.stop ) ) ) {
                    try {
                        variables.task.stop( this );
                        canceled = true;
                    } catch ( any ) {
                        // cancel() fails
                    }
                }
            }
            break;
        default:
            // null/done/failed/cancelled so cancel fails
            break;
        }
        return canceled;
    }

    public any function get() {
        while ( !isDone() ) {
            waitFor( this.SLEEP_UNIT );
        }
        return getResult();
    }

    public any function getWithTimeout( required numeric timeout ) {
        waitForResult( timeout );
        if ( isDone() ) return getResult();
        throw(
            type = "AVOWAL.FUTURE.TIMEOUTEXCEPTION",
            message = "The computation did not complete within #timeout#ms."
        );
    }

    public boolean function isCancelled() {
        return variables.status == "CANCELLED";
    }

    public boolean function isDone() {
        return variables.status != "RUNNING";
    }

    // run can also accept arguments to append to the task
    public any function run() {
        if ( variables.status == "READY" ) {
            var args = 0;
            if ( structKeyExists( arguments, 1 ) && isArray( variables.args ) ) {
                // positional arguments, copy and delete 1st one
                args = [ ];
                for ( var baseArg in variables.args ) {
                    arrayAppend( args, baseArg );
                }
                for ( var arg in arguments ) {
                    arrayAppend( args, arg );
                }
            } else {
                // named arguments, copy and delete task
                args = structCopy( variables.args );
                structAppend( args, arguments );
            }
            var tid = ++request._avowal_tid;
            // we use request scope to avoid copying objects into the thread
            request._avowal_Q[ tid ] = {
                task = variables.task,
                args = args
            };
            variables.status = "RUNNING";
            var threadName = variables.thread.currentThread().getThreadGroup().getName();
            if ( threadName == "cfthread" || threadName == "scheduler" ) {
                var f = request._avowal_Q[ tid ];
                try {
                    if ( isStruct( f.task ) &&
                         structKeyExists( f.task, "call" ) ) {
                        variables.result = f.task.call( argumentCollection = f.args );
                    } else if ( isCustomFunction( f.task ) ||
                                isClosure( f.task ) ) {
                        variables.result = f.task( argumentCollection = f.args );
                    } else {
                        throw(
                            type = "AVOWAL.FUTURE.UNCALLABLE",
                            message = "The computation is not callable."
                        );
                    }
                    terminate( "DONE" );
                } catch ( any e ) {
                    variables.exception = e;
                    terminate( "FAILED" );
                }
            } else {
                thread name="AvowalThread#tid#" tid="#tid#" {
                    var f = request._avowal_Q[ attributes.tid ];
                    try {
                        if ( isStruct( f.task ) &&
                             structKeyExists( f.task, "call" ) ) {
                            variables.result = f.task.call( argumentCollection = f.args );
                        } else if ( isCustomFunction( f.task ) ||
                                    isClosure( f.task ) ) {
                            variables.result = f.task( argumentCollection = f.args );
                        } else {
                            throw(
                                type = "AVOWAL.FUTURE.UNCALLABLE",
                                message = "The computation is not callable."
                            );
                        }
                        terminate( "DONE" );
                    } catch ( any e ) {
                        variables.exception = e;
                        terminate( "FAILED" );
                    }
                }
            }
        }
        return this;
    }

    // should be called by a task to indicate it successfully stopped when asked
    public void function stopped() {
        terminate( "CANCELLED" );
    }

    // called when a task is completed: can be overridden
    private any function done() {
        return this;
    }

    private any function getResult() {
        switch ( variables.status ) {
        case "DONE":
            if ( structKeyExists( variables, "result" ) &&
                 !isNull( variables.result ) ) {
                return variables.result;
            } else {
                return; // return null
            }
            break;
        case "FAILED":
            throw variables.exception;
            break;
        case "RUNNING":
            throw(
                type = "AVOWAL.FUTURE.INTERNALERROR",
                message = "An internal error occurred, attempting to get the result of a running task."
            );
            break;
        default:
            throw(
                type = "AVOWAL.FUTURE.INTERRUPTEDEXCEPTION",
                message = "The computation was cancelled or has not yet run."
            );
            break;
        }
    }

    private void function terminate( required string status ) {
        variables.status = status;
        done();
    }

    private void function waitFor( required numeric timeout ) {
        variables.thread.sleep( timeout );
    }

    private void function waitForResult( required numeric timeout ) {
        var jumps = int( timeout / this.SLEEP_UNIT );
        var hops = timeout mod this.SLEEP_UNIT;
        var startTime = getTickCount();

        for ( var bigtime = 0; bigtime < jumps; ++bigtime ) {
            if ( isDone() ||
                 ( getTickCount() - startTime ) > timeout ) {
                return;
            }
            waitFor( this.SLEEP_UNIT );
        }
        if ( isDone() ||
             ( getTickCount() - startTime ) > timeout ) {
            return;
        }
        waitFor( hops );
    }

}
