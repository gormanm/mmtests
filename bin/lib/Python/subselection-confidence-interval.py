#! /usr/bin/python3

# Script to compute "typical" value and confidence interval half length based
# on averages and variances of subselections. 
#
# See paper:
# Tomas Kalibera, Lubomir Bulej, Petr Tuma: Automated Detection of Performance
# Regressions: The Mono Experience

# Requires: python3-numpy, python3-scipy

import numpy
import sys
import json
from scipy import stats
import os.path

def error(s):
    print(f"{os.path.basename(sys.argv[0])}: Error: {s}", file=sys.stderr)

def fatal_usage():
    print(f"Usage: {os.path.basename(sys.argv[0])} [function [alpha]]", file=sys.stderr)
    exit(1)

def geometric_mean(x):
    a = numpy.array(x)
    return a.prod()**(1.0/len(a))

def harmonic_mean(x):
    return 1/mean(1/x)

def confidence_interval(x, func, alpha, selections=100, fracsize=0.8):
    iters = len(x)

    med = numpy.zeros(iters)

    v = numpy.zeros(iters)

    lens = numpy.zeros(iters, dtype=int)

    for j in range(iters):
        xx = numpy.asarray(x[j], dtype=float)

        lens[j] = int(fracsize * len(xx))

        submean = numpy.zeros(selections)

        for i in range(selections):
            submean[i] = func(numpy.random.choice(xx, lens[j]))

        subvar = numpy.zeros(selections)
        for i in range(selections):
            subvar[i] = numpy.var(numpy.random.choice(xx, lens[j]))

        med[j] = numpy.median(submean)
        v[j] = numpy.median(subvar)

    m = numpy.mean(med)
    svar = numpy.mean(v)
    smean = 0.0
    if iters > 1:
        for j in range(iters):
            smean += (med[j] - m) ** 2 * lens[j]
        smean /= (iters - 1)

    halflength = stats.norm.ppf(1 - alpha / 2) * numpy.sqrt((smean + svar) / numpy.sum(lens))

    return m, halflength

funcdict = {
    "amean": numpy.mean,
    "gmean": geometric_mean,
    "hmean": harmonic_mean
}

funcn = "amean"
alpha = 0.05

if len(sys.argv) > 1:
    funcn = sys.argv[1]

    if len(sys.argv) > 2:
        if len(sys.argv) > 3:
            fatal_usage()

        try:
            alpha=float(sys.argv[2])
        except:
            error(f"Invalid floating point alpha value '{sys.argv[2]}'")
            fatal_usage()

try:
  func = funcdict[funcn]
except:
  error(f"No function matching '{funcn}'. Available functions are {list(funcdict.keys())}")
  fatal_usage()

data = json.load(sys.stdin)
result = confidence_interval(data, func, alpha)
print(*result)
