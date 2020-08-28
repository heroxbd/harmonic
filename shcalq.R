#!/usr/bin/env Rscript
require(argparser)
psr <- arg_parser("GLM Poisson regression and harmonic decomposition")
psr <- add_argument(psr, "ipt", help="input")
psr <- add_argument(psr, "--geo", help="PMT positions")
psr <- add_argument(psr, "--PMT", help="PMT types")
psr <- add_argument(psr, "--offset", help="source offset", short="-s")
psr <- add_argument(psr, "-l", help="order of harmonics", type="integer", default=6)
psr <- add_argument(psr, "-o", help="output")

argv <- parse_args(psr)

source("shcal.R")

PMT <- data.table(read.table(argv$PMT, col.names=c("ChannelID", "type", "QE"),
                            colClasses=c("factor", "factor", NA)), key="ChannelID")
PMT$lQE <- log(PMT$QE)
qr <- qr[PMT]

pl <- geo['ChannelID']
pmtl <- data.table(pmt=pl)
# al <- floor(sqrt(seq(od)))

y <- d[, list(q=nrow(.SD)), by=c("ChannelID", "EventID")]
setkey(y, ChannelID)

mx <- function(x) x[qr]
z <- y[,mx(.SD),by=EventID]
z[is.na(q), q:=0]

require(h2o)
h2o.init(nthreads = 4, port=65281, max_mem_size = "40g")
hz <- as.h2o(z, gsub("/", "_", argv$ipt))

vl <- paste("V", seq(argv$l), sep="")
m <- h2o.glm(c(vl, "EventID", "type", "lQE"), "q", hz, lambda=0, family="poisson", compute_p_values=TRUE, max_iterations=512)
cm <- data.table(m@model$coefficients_table)
setkey(cm, "names")
names(cm)[2] <- "Value"
names(cm)[3] <- "stderr"
cr <- c("Intercept", vl)
sa <- cm[cr]
names(sa)[1] <- "order"
sa$order <- seq(0, argv$l)
fid <- H5Fcreate(argv$o)
h5save(sa, name="coef", file=fid)
ta <- cm[!cr]
h5save(ta, name="event", file=fid)
h5writeAttribute(h2o.aic(m), fid, "AIC")
h5save(oz, name="v0", file=fid, native=TRUE)
H5Fclose(fid)
