#!/usr/bin/env Rscript
require(argparser)

psr <- arg_parser("Quantile regression and GLM t~pmt per event")
psr <- add_argument(psr, "ipt", help="input")
psr <- add_argument(psr, "-j", help="number of jobs", default=1, type="integer")
psr <- add_argument(psr, "--tau", help="tau", type="double", default=0.01)
psr <- add_argument(psr, "--geo", help="PMT positions")
psr <- add_argument(psr, "--offset", help="source offset", short="-s")
psr <- add_argument(psr, "-l", help="order of harmonics", type="integer", default=6)
psr <- add_argument(psr, "-o", help="output")

argv <- parse_args(psr)

if (is.na(argv$offset)) {
    offset <- c(0,0,0)
} else {
    offset <- as.numeric(read.table(argv$offset))
}

geo <- read.table(argv$geo, col.names=c("ChannelID", "theta", "phi"))

require(rhdf5)
require(data.table)
setDTthreads(argv$j)

d <- h5read(argv$ipt, "PETruth")
pl <- sort(unique(d[['ChannelID']]))
npl <- length(pl)
pmtl <- data.table(pmt=pl)

ia <- h5readAttributes(argv$ipt, "/")
z <- ifelse(ia$z, ia$z, 1)
oz <- c(0,0,z) + offset
uz <- as.matrix(oz / sqrt(sum(oz^2)))

geo$theta <- geo$theta / 180 * pi
geo$phi <- geo$phi / 180 * pi
# pz inner uz, but now everything is on z-axis and is not needed.
pv <- matrix(c(sin(geo$theta) * c(cos(geo$phi), sin(geo$phi)), cos(geo$theta)), ncol=3)
leg_x <- as.vector(pv %*% uz)

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
names(csm)[2] <- "stderr"

sa <- csm[1:(argv$l+1),]
sa$order <- 0:argv$l

fid <- H5Fcreate(argv$o)
h5save(sa, name="coef", file=fid, native=TRUE)
h5save(csm[(argv$l+2):nrow(csm),], name="event", file=fid, native=TRUE)
h5save(oz, name="v0", file=fid, native=TRUE)
H5Fclose(fid)
