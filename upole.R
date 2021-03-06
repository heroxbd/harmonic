#!/usr/bin/env Rscript
# poles with systematic uncertainty.

require(plyr)
require(rhdf5)
require(argparser)

psr <- arg_parser("plot coefficients")
psr <- add_argument(psr, "--input", nargs=Inf, help="input coefficients files")
psr <- add_argument(psr, "-o", help="output file")
psr <- add_argument(psr, "--cutoff", type="integer", default=8, help="cut off order of polynomials")
argv <- parse_args(psr)

loadf <- function(fn) {
    fid <- H5Fopen(fn)
    rst <- cbind(h5read(fid, "coef"), direction=basename(dirname(fn)))
    H5Fclose(fid)
    rst
}

d <- ldply(argv$input, loadf)
d$direction <- as.factor(d$direction)

require(orthopolynom)
cutoff <- argv$cutoff
lp <- legendre.polynomials(n=cutoff, normalized=TRUE)

cols <- paste("leg", 0:cutoff, sep='')

d <- cbind(d, as.data.frame(polynomial.values(lp, d$r/17000), col.names=cols))

os <- seq(1, cutoff, by=2)
es <- seq(0, cutoff, by=2)
of <- as.formula(paste("Value ~", paste(c(cols[os+1], "0"), collapse="+")))
ef <- as.formula(paste("Value ~", paste(c(cols[es+1], "0"), collapse="+")))

zl <- seq(0, 17000, 500)
pd <- data.frame()
polyv <- data.frame()

for (o in 1:max(d$order)) {
    rs <- d$order==o
    dp <- d[rs,]

    if (o %% 2) {
        fo <- of
        alp <- lp[os+1]
    } else {
        fo <- ef
        alp <- lp[es+1]
    }
    s <- coef(summary(lm(fo, data=dp)))
    lgs <- s[,1]
    lgs[abs(s[,3]) < 3.5] <- 0 # insignificant

    la <- length(alp)
    r <- 0
    for (i in 1:la){
        r <- r + lgs[i] * alp[[i]]
    }

    polyv <- rbind(polyv, subset(data.frame(poly=0:(length(r)-1), value=coef(r), order=o), value!=0))

    pd <- rbind(pd, data.frame(r=zl, Value=predict(r, zl/17000), order=o))
}

require(ggforce)
pdf(sub(".h5", ".pdf", argv$o), 13, 7)
p <- ggplot(d, aes(x=r, y=Value))
p <- p + xlab("r/mm") + ylab("t/ns")
p <- p + geom_point(aes(color=direction))
p <- p + geom_errorbar(aes(ymin=Value-stderr, ymax=Value+stderr, color=direction))
p <- p + geom_line(data=pd)
p <- p + facet_wrap(~order, scales="free")
print(p)
dev.off()

fid <- H5Fcreate(argv$o)
h5save(polyv, name="polyv", file=fid, native=TRUE)
h5save(pd, name="prediction", file=fid, native=TRUE)
H5Fclose(fid)
