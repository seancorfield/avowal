# Avowal
Futures and Promises for modern CFML, inspired by my earlier cfconcurrency library.

Unlike cfconcurrency, which relied on the Asynchronous CFML Gateway and CFCs for everything, Avowal relies on `thread` internally and closures, so it requires Railo 4, Lucee, or Adobe ColdFusion 10+.

The basic intent behind this library is to provide a simple, fluid interface for creating future values and for orchestrating sequences of those through completable futures (promises).
