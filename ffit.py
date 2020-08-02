#!/usr/bin/env python3
'''
full fit with charge and timing
'''
import argparse, numpy as np, pandas as pd, h5py
from crot import tfit, srql
from scipy.optimize import minimize

mtd = "Powell"

R=18000

x0l = [(0,0,0)] + [(np.arccos(a), b, R) for a in (-2./3, 0., 2./3) for b in (1./3*np.pi, np.pi , 5./3*np.pi)]
bn = ((None, None), (None, None), (-R, R))

def aicg(tx):
    eid = tx.index.values[0] # event_id

    timing.set_chl(tx['ChannelID'].values)

    x0 = x0l[0]

    otd = []
    for x0 in x0l:
        ot = minimize(timing.rql, x0, (tx,), method=mtd, bounds=bn, options={"maxiter": 500, "disp": True})
        if ot.success:
            timing.rql(ot.x[:3], tx)
            ot.T0 = timing.T0
            otd.append(ot)
    assert len(otd) > 0
    ot = min(otd, key=lambda x: x.fun)
    tloss = ot.fun

    z = ot.x[2] * np.cos(ot.x[0])
    h = ot.x[2] * np.sin(ot.x[0])
    x = h * np.cos(ot.x[1])
    y = h * np.sin(ot.x[1])
    rst = (x, y, z, ot.T0, tloss)

    return pd.DataFrame(np.array(rst, dtype=ddtype), index=[eid])
if __name__=='__main__':
    psr = argparse.ArgumentParser()
    psr.add_argument("-o", dest='opt', help="output")
    psr.add_argument("--geo", help="PMT geometry")
    psr.add_argument("--poly", help="polynomial model of Legendre coefficients on radius")
    psr.add_argument('-j', dest="jobs", type=int, default=1, help="number of jobs")
    psr.add_argument('ipt', help="input and selection table output")
    argv = psr.parse_args()

    geo = pd.read_csv(argv.geo, sep=' ', names=("ChannelID", "theta", "phi"))
    geo['theta'] = geo['theta'] / 180 * np.pi
    geo['phi'] = geo['phi'] / 180 * np.pi
    geo['z'] = np.cos(geo['theta'])
    geo['h'] = np.sin(geo['theta'])
    geo['x'] = geo['h'] * np.cos(geo['phi'])
    geo['y'] = geo['h'] * np.sin(geo['phi'])

    with h5py.File(argv.poly, 'r') as ipt:
        polyv = ipt['polyv'][...]

    pord = max(polyv['poly']) + 1
    lord = max(polyv['order']) + 1
    resm = np.zeros((pord, lord))
    for i in range(1, lord):
        sp = polyv[polyv['order']==i]
        resm[sp['poly'], i] = sp['value'] * np.sqrt((2 * sp['poly'] + 1)/2)

    timing = tfit(geo.set_index("ChannelID")[['x', 'y', 'z']], resm)

    ddtype = [(i, np.float32) for i in ("x", "y", "z", "T0", "tloss")]

    # out detector PMTs ranged 30000 ~ 32400 are excluded.
    # >=300000 are small PMTS.
    tt = pd.read_hdf(argv.ipt, 'PETruth').query("ChannelID < 20000 | ChannelID >= 300000").set_index('EventID')

    ol = tt.groupby(tt.index, group_keys=False).apply(aicg)
    ol.index.name="EventID"

    with h5py.File(argv.opt, 'w') as opt:
        opt.create_dataset('ol', data=ol.to_records(), compression="gzip", shuffle=True)
