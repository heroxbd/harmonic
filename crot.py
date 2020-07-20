'''
rotation of z-axis calibrations to an arbitrary direction
'''
import numpy as np
po = np.polynomial.polynomial
lg = np.polynomial.legendre
import numba

class tfit(object):
    def __init__(self, geo, m):
        '''
        v unit vector of the PMTs
        '''
        self.geo = geo
        self.m = m # response matrix [poly, legendre]

    def set_chl(self, chl):
        self.chl = chl
        a, self.ridx = np.unique(chl, return_inverse=True)
        self.ccal = self.geo.loc[a]

    def tcrot(self, par):
        '''
        par: (beta (theta), alpha (phi), rho, lambda0/T0)
        gives the t dependence on the sphere, parameterized in Legendre x.
        '''
        if abs(par[2]) < 1:
            return np.zeros_like(self.chl)
        else:
            z = par[2] * np.cos(par[0])
            h = par[2] * np.sin(par[0])
            x = h * np.cos(par[1])
            y = h * np.sin(par[1])

            u = np.array([x,y,z]) / par[2]
            lx = np.inner(u, self.ccal.values) # x of Legendre

            return lg.legval(lx, po.polyval(par[2] / 17000, self.m))[self.ridx]

    def rql(self, par, tx):
        '''
        par: (beta (theta), alpha (phi), rho)
        tx uses pmt as index
        '''
        self.T0, rst = wp(tx.PETime.values - self.tcrot(par), np.ones(len(tx)))
        return rst

tau = 0.10

@numba.jit(nopython=True)
def wp(d0, weights):
    '''
    get the optimal T0
    '''
    ind = np.argsort(d0)
    v = np.sum(weights)*tau
    w = 0
    for j in range(0,ind.shape[0]):
        v -= weights[ind[j]] * tau
        w += weights[ind[j]] * (1-tau)
        if w>=v:
            x = d0[ind[j]]
            if w==v and j+1 < ind.shape[0]:
                x = (d0[ind[j]] + d0[ind[j+1]]) / 2.
            break
    return x, srql(x, d0, weights)

@numba.jit(nopython=True)
def srql(t0, _t, _q):
    ue = (_t - t0)*_q
    # 0.15 * tze(>0) + 0.85 * tze(<0)
    # = 0.15 * (|tze| + tze) / 2 + 0.85 * (|tze| - tze) /2
    # = |tze| / 2 - 0.35 * tze
    # change to 0.01 quantile: (0.99 - 0.01)/2 = 0.49
    # return ne.evaluate("sum(ue)")/2
    return np.sum(np.abs(ue)/2 - (0.5-tau) * ue)
