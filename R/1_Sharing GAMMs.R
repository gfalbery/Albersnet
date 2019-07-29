
# Running Frequentist GAMS

# Rscript "R Code/1_Sharing Models/1a_Frequentist GAMs.R"

library(mgcv); library(tidyverse); library(ggregplot)

Resps <- c("VirusBinary","RNA","DNA","Vector","NVector")

Covar <- c("s(Phylo, by = ordered(Gz))",
           "t2(Phylo, Space, by = ordered(!Gz))",
           "MinCites",
           "Domestic",
           "Spp")

BAMList <- DataList <- PPList <- list()

r = 1

for(r in 1:length(Resps)){
  
  print(Resps[r])
  
  DataList[[Resps[r]]] <- FinalHostMatrix[!NARows(FinalHostMatrix, Resps[r]),] %>% droplevels
  
  DataList[[Resps[r]]]$Sp <- factor(DataList[[Resps[r]]]$Sp, levels = sort(union(DataList[[Resps[r]]]$Sp,DataList[[Resps[r]]]$Sp2)))
  DataList[[Resps[r]]]$Sp2 <- factor(DataList[[Resps[r]]]$Sp2, levels = sort(union(DataList[[Resps[r]]]$Sp,DataList[[Resps[r]]]$Sp2)))
  
  DataList[[Resps[r]]] <- DataList[[Resps[r]]] %>% slice(order(Sp, Sp2))
  
  MZ1 <- model.matrix( ~ Sp - 1, data = DataList[[Resps[r]]]) %>% as.matrix
  MZ2 <- model.matrix( ~ Sp2 - 1, data = DataList[[Resps[r]]]) %>% as.matrix
  
  SppMatrix = MZ1 + MZ2
  
  DataList[[Resps[[r]]]]$Spp <- SppMatrix
  DataList[[Resps[[r]]]]$Cites <- rowSums(log(DataList[[Resps[r]]][,c("hDiseaseZACites","hDiseaseZACites.Sp2")] + 1))
  DataList[[Resps[[r]]]]$MinCites <- apply(log(DataList[[Resps[r]]][,c("hDiseaseZACites","hDiseaseZACites.Sp2")] + 1),1,min)
  DataList[[Resps[[r]]]]$Domestic <- ifelse(rowSums(cbind(2- DataList[[Resps[r]]]$hDom %>% as.factor %>% as.numeric,
                                                          2- DataList[[Resps[r]]]$hDom.Sp2 %>% as.factor %>% as.numeric))>0,1,0)
  
  PPList[[Resps[r]]] <- list(Spp = list(rank = nlevels(DataList[[Resps[r]]]$Sp), 
                                        diag(nlevels(DataList[[Resps[r]]]$Sp))))
  
  Formula = as.formula(paste0(Resps[r], 
                              " ~ ",
                              paste(Covar, collapse = " + ")
  ))
  
  BAMList[[Resps[r]]] <- bam(Formula,
                             data = DataList[[Resps[r]]], 
                             family = binomial(),
                             paraPen = PPList[[Resps[r]]], select = T
  )
  
}

save(DataList, PPList, BAMList, file = "Output Files/BAMList.Rdata")

# Using this to make outputs ####

FitList <- PostList <- DrawList <- list()

r = 1

for(r in 1:length(BAMList)){
  
  Model <- BAMList[[Resps[r]]]
  
  print(Resps[r])
  
  # Model Checking ####
  
  SpCoefNames <- names(Model$coef)[substr(names(Model$coef),1,5)=="SppSp"]
  SpCoef <- Model$coef[SpCoefNames]
  
  # Effects ####
  
  SpaceRange <- seq(from = 0,
                    to = 1,
                    length = 101) %>% 
    c(mean(DataList[[Resps[r]]]$Space))
  
  PhyloRange <- seq(from = 0,
                    to = 1,
                    length = 101)  %>% 
    c(mean(DataList[[Resps[r]]]$Phylo))
  
  FitList[[Resps[r]]] <- expand.grid(Space = SpaceRange,
                                     Phylo = PhyloRange,
                                     MinCites = mean(DataList[[Resps[r]]]$MinCites),
                                     Domestic = 0
  ) %>%
    mutate(SpaceQuantile = ifelse(Space == last(unique(Space)), "1.5%",
                                  ifelse(Space == 0, "0%",
                                         ifelse(Space == 0.25, "25%",
                                                ifelse(Space == 0.5, "50%", NA)))),
           
           PhyloQuantile = ifelse(Phylo == last(unique(Phylo)), "0.1",
                                  ifelse(Phylo == 0, "0",
                                         ifelse(Phylo == 0.25, "0.25",
                                                ifelse(Phylo == 0.5, "0.5", NA)))),
           Gz = as.numeric(Space==0))
  
  FitList[[Resps[r]]]$Spp <- matrix(0 , nrow = nrow(FitList[[Resps[r]]]), ncol = length(SpCoef))
  
  FitPredictions  <- predict.gam(Model, 
                                 newdata = FitList[[Resps[r]]], 
                                 se.fit = T)
  
  FitList[[Resps[r]]][,c("Fit","Lower", "Upper")] <- logistic(with(FitPredictions, cbind(fit, fit - se.fit, fit + se.fit)))
  
  print("Getting posterior uncertainty!")
  
  # Posterior Uncertainty Simulation #### https://www.fromthebottomoftheheap.net/2014/06/16/simultaneous-confidence-intervals-for-derivatives/
  
  for(i in c("Space", "Phylo")){
    
    print(i)
    
    PredData <- FitList[[Resps[r]]] 
    
    if(i == "Space") PredData <- PredData %>% filter(Phylo == last(unique(Phylo))) else{
      
      PredData <- PredData %>% filter(Space == 0)
      
    }
    
    lp <- predict(Model, newdata = PredData, 
                  type = "lpmatrix") %>% 
      as.data.frame()
    
    coefs <- coef(Model)
    vc <- vcov(Model)
    
    sim <- mvrnorm(100, mu = coefs, Sigma = vc)
    
    want <- lp %>% colnames
    
    lp <- lp %>% as.matrix #%>% logistic
    
    fits <- lp[, want] %*% t(sim[, want]) %>% as.data.frame() %>%
      mutate(i = PredData[,i])
    
    PostList[[Resps[r]]][[i]] <- gather(fits, key = "Draw", value = "Fit", -i) %>%
      mutate(Fit = logistic(Fit))
    
  }
  
  Draw = F
  
  if(Draw){
    
    DrawList[[Resps[r]]] <- list()
    
    for(i in c("Space", "Phylo")){
      
      print(i)
      
      lp = list()
      
      for(j in 1:100){
        
        print(j)
        
        PredData <- FitList[[Resps[r]]]
        
        if(i == "Space"){
          
          PredData <- PredData %>% filter(Phylo == last(unique(Phylo))) %>%
            mutate(Phylo = sample(DataList[[Resps[r]]]$Phylo, 1))
          
        } else {
          
          PredData <- PredData %>% filter(Space == last(unique(Space))) %>%
            mutate(Space = sample(DataList[[Resps[r]]]$Space, 1))
          
        }
        
        lp[[j]] <- data.frame(Fit = predict(Model, newdata = PredData),
                              Iteration = as.factor(j),
                              i = PredData[,i])
        
      }
      
      DrawList[[Resps[r]]][[i]] <- lp %>% bind_rows() %>% as.data.frame() %>%
        mutate(Fit = logistic(Fit))
      
    }
  }
  
}

save(FitList, PostList, DrawList, file = "Output Files/FitList.Rdata")

# Validating the model and getting deviance contributions 


Iterations = 10

Resps <- c("VirusBinary","RNA","DNA","Vector","NVector")

y = Resps[1]

RealOutcomes <- DataList[[y]][,y]

RealPredictions <- predict.bam(BAMList[[y]], 
                               newdata = DataList[[y]]) %>% logistic

InterceptPredictions <- rep(mean(RealPredictions), nrow(DataList[[y]]))

RandomPredictionList <- DevianceList <- list()

for(x in c("Space", "Phylo", "MinCites", "Domestic","Spp")){
  
  print(x)
  
  for(i in 1:Iterations){
    
    print(i)
    
    PredDF <- DataList[[1]]
    
    PredDF[,x] <- PredDF %>% slice(sample(1:n())) %>% pull(x)
    
    if(x == "Space"){
      PredDF <- PredDF %>% mutate(Gz = as.numeric(Space == 0))
    }
    
    Predictions <- predict.bam(BAMList[[y]], 
                               newdata = PredDF)
    
    RandomPredictionList[[x]][[i]] <- logistic(Predictions)
    
    ModelLikelihood = dbinom(RealOutcomes, 1, RandomPredictionList[[x]][[i]], log = TRUE) %>% sum
    
    Deviance = -2*ModelLikelihood
    
    DevianceList[[x]][[i]] <- Deviance
  }
}

RealModelLikelihood = dbinom(RealOutcomes, 1, RealPredictions, log = TRUE) %>% sum
RealDeviance = -2*RealModelLikelihood

InterceptModelLikelihood = dbinom(RealOutcomes, 1, InterceptPredictions, log = TRUE) %>% sum
InterceptDeviance = -2*InterceptModelLikelihood

sapply(DevianceList, mean) %>% c(Real = RealDeviance, Intercept = InterceptDeviance)

DevianceAccounted = 1 - RealDeviance/InterceptDeviance

# Keeping the vector constant ####

Iterations = 10

Resps <- c("VirusBinary","RNA","DNA","Vector","NVector")

y = Resps[1]

RealOutcomes <- DataList[[y]][,y]

RealPredictions <- predict.bam(BAMList[[y]], 
                               newdata = DataList[[y]]) %>% logistic

InterceptPredictions <- rep(mean(RealPredictions), nrow(DataList[[y]]))

RandomPredictionList <- DevianceList <- list()

for(x in c("Space", "Phylo", "MinCites", "Domestic","Spp")){
  
  print(x)
  
  PredDF <- DataList[[1]]
  
  SaveVector <- PredDF[,y]
  
  for(i in 1:Iterations){
    
    print(i)
    
    PredDF <- PredDF %>% slice(sample(1:n()))
    PredDF[,x] <- SaveVector
    
    if(x == "Space"){
      PredDF <- PredDF %>% mutate(Gz = as.numeric(Space == 0))
    }
    
    Predictions <- predict.bam(BAMList[[y]], 
                               newdata = PredDF)
    
    RandomPredictionList[[x]][[i]] <- logistic(Predictions)
    
    ModelLikelihood = dbinom(RealOutcomes, 1, RandomPredictionList[[x]][[i]], log = TRUE) %>% sum
    
    Deviance = -2*ModelLikelihood
    
    DevianceList[[x]][[i]] <- Deviance
    
  }
}

RealModelLikelihood = dbinom(RealOutcomes, 1, RealPredictions, log = TRUE) %>% sum
RealDeviance = -2*RealModelLikelihood

InterceptModelLikelihood = dbinom(RealOutcomes, 1, InterceptPredictions, log = TRUE) %>% sum
InterceptDeviance = -2*InterceptModelLikelihood

sapply(DevianceList, mean) %>% c(Real = RealDeviance, Intercept = InterceptDeviance)

DevianceAccounted = 1 - RealDeviance/InterceptDeviance