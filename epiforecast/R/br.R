## author_header begin
## Copyright (C) 2016 Sangwon Hyun, Ryan J. Tibshirani, Logan C. Brooks
##
## This file is part of epiforecast.  Algorithms included in epiforecast were developed by Logan C. Brooks, David C. Farrow, Sangwon Hyun, Shannon Gallagher, Ryan J. Tibshirani, Roni Rosenfeld, and Rob Tibshirani (Stanford University), members of the Delphi group at Carnegie Mellon University.
##
## Research reported in this publication was supported by the National Institute Of General Medical Sciences of the National Institutes of Health under Award Number U54 GM088491. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health. This material is based upon work supported by the National Science Foundation Graduate Research Fellowship Program under Grant No. DGE-1252522. Any opinions, findings, and conclusions or recommendations expressed in this material are those of the authors and do not necessarily reflect the views of the National Science Foundation. David C. Farrow was a predoctoral trainee supported by NIH T32 training grant T32 EB009403 as part of the HHMI-NIBIB Interfaces Initiative. Ryan J. Tibshirani was supported by NSF grant DMS-1309174.
## author_header end
## license_header begin
## epiforecast is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, version 2 of the License.
##
## epiforecast is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with epiforecast.  If not, see <http://www.gnu.org/licenses/>.
## license_header end

##' @include utils.R
##' @include match.R
NULL

## fixme preseason weight discount
## fixme breaks on t=0

##' Function for making forecasts with the basis regression method
##'
##' Estimates missing values in \code{dat.obj[[cur.season]]} by regressing the
##' mean of "pseudo-trajectories" formed from non-\code{NA} observations from
##' \code{dat.obj[[cur.season]]} and "pseudo-observations" formed from
##' \code{dat.obj[-cur.season]} on a set of basis elements.
##'
##' First, constructs a pseudo-trajectory for each training trajectory
##' (\code{dat.obj[-cur.season]}) by shifting the training trajectory so that
##' the maximum of its observations at times where \code{dat.obj[[cur.season]]}
##' is non-\code{NA} aligns more closely with the maximum of
##' \code{dat.obj[[cur.season]]} (where it is non-\code{NA}); the alignment
##' procedure consists of a time shift (so that the partial maximum of the
##' training and test trajectories are the same) and a scale (controlled by
##' \code{scale.method}, \code{baseline}, and \code{max.scale.factor}). The
##' pseudo-trajectory is formed by taking \code{dat.obj[[cur.season]]} where it
##' is non-\code{NA} and the aligned training trajectory where
##' \code{dat.obj[[cur.season]]} is \code{NA}.
##'
##' Second, the mean of the pseudo-trajectories is regressed on a collection of
##' basis elements to produce a single curve that provides estimates for
##' \code{dat.obj[[cur.season]]} where it is \code{NA}.
##'
##' @param dat.obj assumed to be a list, of length equal to number of past
##'   seasons. Each item here is itself a list, each component containing a
##'   vector of "signals" for that seasons.
##' @param cur.season the number of the season to be forecast. Must be in
##'   between 1 and the length of dat.obj.
##' @param control.list Contains simulation settings.
##'
##' @return a numeric vector containing a smoothed version of the past
##'   observations and future "pseudo-observations" (predictions).
##'
##' @author Logan C. Brooks, David C. Farrow, Sangwon Hyun, Ryan J. Tibshirani, Roni Rosenfeld
##'
##' @export
br.smoothedCurve = function(full.dat, dat.obj, cur.season,
                            control.list = get.br.control.list()){

    if(control.list$model!="Basis Regression") stop("Wrong control list! Use the right one for basis regression!")

    ## Manually extracting objects from control.list
    n.out=control.list$n.out
    df = control.list$df
    w = control.list$w
    smooth = control.list$smooth
    basis = control.list$basis
    max.scale.factor = control.list$max.scale.factor
    cv.rule = control.list$cv.rule
    scale.method = control.list$scale.method
    baseline = control.list$baseline
    max.match.length = control.list$max.match.length 

    ## Split and check full.dat
    check.list.format(full.dat)
    old.dat = head(full.dat, -1L)
    new.dat = tail(full.dat, 1L)[[1]]
    old.season.labels = head(names(full.dat), -1L)
    new.season.label = tail(names(full.dat), 1L)

    ## Build spline basis
    ns = length(full.dat)-1
    y = new.dat
    x = seq_along(y)
    if (is.null(max.match.length)) max.match.length <- sum(!is.na(y))
    n = length(y)
    obs = which(!is.na(y))
    obs.match = tail(obs, max.match.length)
    obs.nomatch = obs[seq_len(length(obs)-length(obs.match))]
    weights = rep(1,n); weights[-obs] <- w; weights[obs.nomatch] <- w
    b = splines::bs(x, df=df)
    ytil = y                # On obs time points, just use current y
    zmat = matrix(0,n,ns-1) # On unobs time points, use past data
  
    ## Creating pseudo-observations from past seasons
    for (i in (1:(ns-1))) {
      yp = full.dat[[i]]
      xp = seq_along(yp)
      yp = approx(xp,yp,xout=x,rule=2)$y
  
      if (length(obs) > 0 && scale.method != "none") {
        ## fixme negative scale factors
        ## Scale past signals to have the right max value on the
        ## obs time points, subject to being above the baseline
        if (is.na(baseline)) {
          ## Scale about 0:
          scale.factor = switch(scale.method,
                                max = max(y[obs])/max(yp[obs]),
                                last = tail(y[obs],1)/tail(yp[obs],1)
                                )
          if (is.nan(scale.factor)) scale.factor <- 1
          scale.factor <- max(1/max.scale.factor, min(max.scale.factor, scale.factor))
          yp <- yp * scale.factor
        } else if (max(y[obs]) > baseline) {
          ## Scale above and about baseline:
          ii = which(yp >= baseline)
          scale.factor = switch(scale.method,
                                max = (max(y[obs])-baseline)/(max(yp[obs])-baseline),
                                last = (tail(y[obs],1)-baseline)/(tail(yp[obs],1)-baseline)
                                )
          if (is.nan(scale.factor)) scale.factor <- 1
          scale.factor <- max(1/max.scale.factor, min(max.scale.factor, scale.factor))
          yp[ii] <- (yp[ii]-baseline) * scale.factor + baseline
        }
  
        ## Shift past signals to have the right arg max on the obs time points:
        del = which.max(y[obs])-which.max(yp[obs])
        yp = approx(x+del,yp,xout=x,rule=2)$y
      }
  
      zmat[,i] = yp
    }
    z = rowMeans(zmat)
    ytil[-obs] = z[-obs]
  
    ## Don't smooth in weird cases that cv.glmnet cannot handle.
    if (!smooth) return (ytil)
    if (any(is.na(ytil))) { warning("any(is.na(ytil))")  }
    if (any(is.infinite(ytil))) { warning("any(is.infinite(ytil))")  }
    if (any(is.na(weights))) { warning("any(is.na(weights))")  }
    if (any(is.infinite(weights))) {  warning("any(is.infinite(weights))")  }
    if (any(is.na(ytil)) || any(is.infinite(ytil)) || any(is.na(weights)) || any(is.infinite(weights))) {
      return (as.matrix(ytil))
    }

    ## Run basis regression with elastic net penalties
    out = glmnet::cv.glmnet(b,ytil,weights,nfolds=5,alpha=0.5)
    if (cv.rule=="min") {
        lambda = out$lambda.min
    } else if (cv.rule == "1se") {
        lambda = out$lambda.1se
    } else {
        stop(paste(cv.rule, "not written yet!"))
    }
    result = predict(out$glmnet.fit, newx=b, s=lambda)
    result = as.vector(result)

    ## fixme find out why these cases occur, prevent, remove checks, or make
    ## checks apply to methods with different ranges
    if (any(result>100)) {
      warning("any(result>100)")
      if (any(ytil>100))
        stop("any(ytil>100)")
      return (ytil)
    }

    return (result)
}

##' Function for making forecasts with the basis regression method with output
##' matching the format of distributional forecasting methods.
##'
##' @template sim.method_template
##'
##' @param ... arguments to forward to \code{\link{br.smoothedCurve}}.
##'
##' @details For the basis regression method, there is a single column per
##'   trajectory in \code{new.dat} containing the smoothed curve outputted by
##'   \code{\link{br.smoothedCurve}}, unless \code{max.n.sims} is
##'   non-\code{NULL}, in which case, it is a resampling of these smoothed
##'   curves.
##'
##' @examples
##' fluview.nat.recent.df =
##'    trimPartialPastSeasons(fetchEpidataDF("fluview", "nat",
##'                           first.week.of.season=21L,
##'                           cache.file.prefix="fluview_nat_allfetch"),
##'            "wili", min.points.in.season=52L)
##' ## Recent historical seasons + current season, minus 2009 (nonseasonal
##' ## pandemic) season:
##' full.dat = split(fluview.nat.recent.df$wili, fluview.nat.recent.df$season)
##' names(full.dat) <- sprintf("S%s", names(full.dat))
##' full.dat <- full.dat[names(full.dat)!="S2009"]
##' sim = br.sim(full.dat, baseline = 2.1)
##'
##' @author Logan C. Brooks, David C. Farrow, Sangwon Hyun, Ryan J. Tibshirani, Roni Rosenfeld
##'
##' @export
    br.sim = function(full.dat, new.dat.sim, max.n.sims, baseline=0, bootstrap = FALSE,
                      control.list = get_br_control_list(), ...) {

    ## Check input
    check.list.format(full.dat)
    n.sims = if (bootstrap) max.n.sims else 1L

    ## Update control list with baseline and max.n.sims, because br.smoothedCurve needs this information
    control.list = get_br_control_list(parent = control.list,
                                       baseline = baseline,
                                       max.n.sims = max.n.sims)

    ## Split into old dat (list) and new dat (vector)
    old.dat = head(full.dat, -1L)
    new.dat = tail(full.dat, 1L)[[1]]
    old.season.labels = head(names(full.dat), -1L)
    new.season.label = tail(names(full.dat), 1L)

    ## simulate trajectories by bootstrapping old trajectories
    one.bootstrap = function(old.dat, new.dat, bootstrap = T){
        bootstrap.inds= sample(x = seq_along(old.dat),
                               size = length(old.dat),
                               replace = TRUE,
                               prob = control.list$prob)
        bootstrap.old.dat = old.dat[bootstrap.inds]
        bootstrap.full.dat = c(bootstrap.old.dat, list(new.dat))
        names(bootstrap.full.dat)[length(bootstrap.full.dat)] = new.season.label
        br.fitted.curve = br.smoothedCurve(full.dat = bootstrap.full.dat,
                                           control.list = control.list)
        return(br.fitted.curve) 
    }

    ## if bootstrap is FALSE, then return the single prediction.
    ys = replicate(n.sims, one.bootstrap(old.dat,new.dat,bootstrap), simplify="array")
    weights = rep(1/n.sims, n.sims)

    ## Bundle into an object of 'sim' class
    sim = list(ys=ys,
               weights=weights,
               old.dat = list(old.dat)[[1]],
               new.dat = (new.dat),
               old.season.labels = (old.season.labels),
               new.season.label = (new.season.label),
               control.list = list(control.list)[[1]])
    class(sim) <- "sim"
    return (sim)
}
