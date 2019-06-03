#
# Script to compute "typical" value and confidence interval half length based
# on averages and variances of subselections. See paper:
# Tomas Kalibera, Lubomir Bulej, Petr Tuma: Automated Detection of Performance
# Regressions: The Mono Experience
#

library("rjson")

hmean <- function(x)
{
	return(1/mean(1/x))
}

gmean <- function(x)
{
	return(prod(x)^(1/length(x)))
}

subselection.confidence.interval <- function(x, mean.func="mean", selections=100, fracsize=0.8, alpha=0.05)
{
	iters <- length(x)
	med <- vector(mode = "numeric", length = iters)
	v <- vector(mode = "numeric", length = iters)
	lens <- vector(mode = "numeric", length = iters)
	for (j in 1:iters) {
		xx <- as.numeric(x[[j]])
		lens[j] <- as.integer(fracsize * length(xx))
		submean <- vector(mode = "numeric", length = selections)
		for (i in 1:selections)
			submean[i] <- do.call(mean.func, list(sample(xx, lens[j], replace=TRUE)))
		subvar <- vector(mode = "numeric", length = selections)
		for (i in 1:selections)
			subvar[i] <- var(sample(xx, lens[j], replace=TRUE))
		med[j] <- median(submean)
		v[j] <- median(subvar)
	}
	m <- mean(med)
	svar <- mean(v)
	smean <- 0
	if (iters > 1) {
		for (j in 1:iters) {
			smean <- smean + (med[j] - m)^2 * lens[j]
		}
		smean <- smean / (iters - 1)
	}
	halflength <- qnorm(1-alpha/2)*sqrt((smean + svar) / sum(lens))
	return(c(m, halflength))
}

mean.name.to.func <- function(name)
{
	if (name == "gmean") {
		return("gmean")
	}
	if (name == "hmean") {
		return("hmean")
	}
	return("mean")
}

data <- fromJSON(file="stdin")

args = commandArgs(trailingOnly=TRUE)
mean.func = "mean"
if (length(args) > 0) {
	mean.func = mean.name.to.func(args[[1]])
}

result <- subselection.confidence.interval(data, mean.func)

print(result)
