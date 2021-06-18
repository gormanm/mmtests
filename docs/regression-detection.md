# Performance Analysis and Regression Detection in MMTests

In mmtests, the performance of a system is analyzed through a set of
benchmarks.  In particular, for a given benchmark, regressions are
detected by comparing results for the system under test with results
for a reference system, or for multiple reference systems.  In terms
of hardware, reference systems usually coincide with that under test,
but they differ in software configuration.  For example, the system
under test may run a different kernel version than the reference
systems.

## Iterations and Statistics

Each benchmark measures a set of quantities of interest (times, rates,
...).  The benchmark is usually executed multiple times.  Each
execution is referred to as an iteration. On each iteration, the
benchmark usually outputs a sample (measurement) for each quantity of
interest.  In more complex scenarios, a benchmark may produce multiple
samples for each iteration.  This case is described in
[the below Section](#advanced-version-of-automatic-regression-detection).

Regardless of how many samples a benchmark produces for each
iteration, data is then comprised of multiple samples.  Samples are
obtained, on one side, for the system under test, and, on the other
side, for the reference system(s).  Statistics are computed over these
samples: min, max, average, standard deviation,
...  In this respect, averages are computed in two different ways,
depending on the type of quantities.  If quantities are not rates
(e.g, they are time) then averages are computed as arithmetic means
(Amean).  If quantities are rates, then averages are computed as
Harmonic means (Hmean).  See the example on average speed in
["Harmonic_mean"](https://en.wikipedia.org/wiki/Harmonic_mean) for
an explanation for why using Hmean for rates.

## Base Version of Automatic Regression Detection

For each quantity of interest, the benchmark produces one sample for
each iteration.  Both sets of samples (the ones for the system under
test and the ones for the reference system) are assumed to belong to a
normal distribution.  Under this assumption, two alternatives are
possible:
(1) Both distributions match, i.e., the two systems have essentially
the same performance for that figure of merit.
(2) The distributions do differ, i.e., one of the two systems
actually underperforms.

mmtests distinguishes between cases (1) and (2) by executing a Welch's
t-test.  In simple terms, case (2) holds if the difference between the
averages is too high, given the values of the standard deviations for
the two sets of samples.  In such a case, the difference in averages
is highlighted, typographically, with a pair of stars (\*).  Recall
that averages may be either Ameans or Hmeans, depending on the nature
of the quantities.

## Advanced Version of Automatic Regression Detection

Results may be influenced by the initial conditions of the system, and
may suffer from outliers.  mmtests addresses these two issues by
modifying the above base mechanism as follows (the underlying theory can
be found in [[1](#ref1), [2](#ref2), [3](#ref3)]).

Because of the first issue, if iterations are repeated at different
times, results may differ.  To offset these biases, mmtests executes
several iterations as usual, yet it expects the benchmark to produce
multiple samples (for each quantity of interest) in each iteration.
So, if different initial conditions do lead to different results, then
some iterations yield different results than others.  The actual
average performance is then obtained by computing cross-iteration
statistics: each iteration gives an average for its series of samples,
and the average over these averages is computed as a measure of the
performance of the system (the situation is a little bit more
complicated, because this overall average is actually computed over
medians of averages, as explained in a moment).  This latter measure
is evidently more robust, against varying initial conditions, than
individual averages.  In addition, variability can now be measured
across iterations, through standard deviation or confidence intervals
over per-iteration averages.

As for the second issue, namely the presence of outliers, mmtests does
not compute simply individual averages for each iteration.  In
contrast, for each iteration, it generates 100 random subselections of
samples chosen at random.  Each subselection contains 80% of the total
samples.  For each such subselection, mmtests computes the average
over the selected samples.  Then, for each iteration, mmtests computes
the median over these per-subselection averages.  Such a median
is provably more robust against outliers [[2]](#ref2).  Finally, the
average of these medians is reported as a measure of the performance of
the system.

# References

* <a name="ref1">[1]</a> [Quality Assurance in Performance: Evaluating Mono Benchmark Results](https://link.springer.com/chapter/10.1007/11558569_20)
* <a name="ref2">[2]</a> [Automated detection of performance regressions: the mono experience](https://ieeexplore.ieee.org/document/1521132)
* <a name="ref3">[3]</a> [Precise Regression Benchmarking with Random Effects: Improving Mono Benchmark Results](https://link.springer.com/chapter/10.1007/11777830_5)
