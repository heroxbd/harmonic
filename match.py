#!/usr/bin/env python3

from ffit import loadp
import argparse, numpy as np, pandas as pd
from matplotlib import pyplot as plt

po = np.polynomial.polynomial

psr = argparse.ArgumentParser()
psr.add_argument("-o", dest='opt', help="output")
psr.add_argument("--poly", help="polynomial model of Legendre coefficients on radius")
psr.add_argument('ipt', help="input and selection table output")
argv = psr.parse_args()

calib = pd.read_hdf(argv.ipt, "coef")['Value'].values[1:]

m = loadp(argv.poly)

rl = np.arange(12000, 17000, 50)

plt.plot(rl, [np.linalg.norm(po.polyval(r / 17000, m)[1:] - calib) for r in rl])
plt.savefig(argv.opt)
