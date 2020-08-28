#!/usr/bin/env Rscript
require(argparser)

psr <- arg_parser("Quantile regression and GLM t~pmt per event")
psr <- add_argument(psr, "ipt", help="input")
psr <- add_argument(psr, "--tau", help="tau", type="double", default=0.01)
psr <- add_argument(psr, "--geo", help="PMT positions")
psr <- add_argument(psr, "--offset", help="source offset", short="-s")
psr <- add_argument(psr, "-l", help="order of harmonics", type="integer", default=6)
psr <- add_argument(psr, "-o", help="output")

argv <- parse_args(psr)

source("shcal.R")

setkey(d, ChannelID)

evn <- nlevels(d$EventID)
tx <- qr[d, nomatch=0]

fm <- as.formula(paste("PETime~", paste("V", seq(argv$l), sep="", collapse="+"), "+EventID", sep=""))

require(quantreg)
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
