if (is.na(argv$offset)) {
    offset <- c(0,0,0)
} else {
    offset <- as.numeric(read.table(argv$offset))
}

geo <- read.table(argv$geo, col.names=c("ChannelID", "theta", "phi"),
                 colClasses=c("factor", NA, NA))

require(rhdf5)

d <- h5read(argv$ipt, "PETruth")

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
require(data.table)

qr <- data.table(t(laply(legendre.polynomials(argv$l, norm=TRUE)[2:(argv$l+1)],
                        function(p) as.function(p)(leg_x))))

qr$ChannelID <- geo$ChannelID
setkey(qr, ChannelID)

d <- data.table(d)
d$ChannelID <- as.factor(d$ChannelID)
d$EventID <- as.factor(d$EventID)
