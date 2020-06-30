#!/usr/bin/env Rscript
require(argparser)

psr <- arg_parser("Quantile regression and GLM t~pmt per event")
psr <- add_argument(psr, "ipt", help="input")
psr <- add_argument(psr, "-j", help="number of jobs", default=1, type="integer")
psr <- add_argument(psr, "--tau", help="tau", type="double", default=0.01)
psr <- add_argument(psr, "--geo", help="PMT positions")
psr <- add_argument(psr, "-l", help="order of harmonics", type="integer", default=6)
psr <- add_argument(psr, "-o", help="output")

argv <- parse_args(psr)

geo <- read.table(argv$geo, col.names=c("ChannelID", "theta", "phi"))

od <- argv$l^2 - 1

if (argv$j > 1) {
    require(doParallel)
    registerDoParallel(cores=argv$j)
}

require(rhdf5)
require(data.table)
d <- h5read(argv$ipt, "PETruth")
pl <- sort(unique(d[['ChannelID']]))
npl <- length(pl)
pmtl <- data.table(pmt=pl)

ia <- h5readAttributes(argv$ipt, "/")
z <- ifelse(ia$z, ia$z, 1)
uz <- c(0,0,z) / abs(z)

geo$theta <- geo$theta / 180 * pi
geo$phi <- geo$phi / 180 * pi
# pz inner uz, but now everything is on z-axis and is not needed.
leg_x <- pz <- cos(geo$theta)

require(orthopolynom)
require(plyr)

qr <- data.table(t(laply(legendre.polynomials(argv$l, norm=TRUE)[2:(argv$l+1)],
                        function(p) as.function(p)(leg_x))))
qr$ChannelID <- as.factor(geo$ChannelID)
setkey(qr, ChannelID)

require(quantreg)

d <- data.table(d)
d$ChannelID <- as.factor(d$ChannelID)
d$EventID <- as.factor(d$EventID)
setkey(d, ChannelID)

evn <- nlevels(d$EventID)
tx <- qr[d, nomatch=0]

fm <- as.formula(paste("PETime~", paste("V", seq(argv$l), sep="", collapse="+"), "+EventID", sep=""))

m <- rq(fm, data=tx, tau=argv$tau, method="pfn")
sm <- summary(m, se="ker")

csm <- as.data.frame(coef(sm))

fid <- H5Fcreate(argv$o)
h5save(csm[1:(argv$l+1),], name="coef", file=fid, native=TRUE)
h5save(csm[(argv$l+2):nrow(csm),], name="event", file=fid, native=TRUE)
H5Fclose(fid)

# sa <- cm[1:(argv$l+1)]
# h5save(sa, file=fid)
# ta <- cm[(argv$l+2):length(cm)]
# h5save(ta, file=fid, createnewfile = FALSE)
