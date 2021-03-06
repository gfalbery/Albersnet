# 0d_Final Dataset Creation ####

library(tidyverse);library(Matrix); library(parallel); library(mgcv); library(ggregplot)

# Removing non-eutherian mammals ####

NonEutherians <- c("Diprotodontia",
                   "Dasyuromorphia",
                   "Paucituberculata",
                   "Didelphimorphia",
                   "Microbiotheria",
                   "Peramelemorphia", 
                   "Notoryctemorphia",
                   "Monotremata")

Panth1 <- read.delim("data/PanTHERIA_1-0_WR05_Aug2008.txt") %>%
  dplyr::rename(Sp = MSW05_Binomial, hOrder = MSW05_Order)
Panth1$Sp <- Panth1$Sp %>% str_replace(" ", "_")

NonEutherianSp <- Panth1[Panth1$hOrder%in%NonEutherians,"Sp"]

FinalHostNames <- reduce(list(
  rownames(FullRangeAdj), 
  colnames(FullSTMatrix),
  rownames(HostAdj)), intersect)

FHN <- FinalHostNames %>% setdiff(NonEutherianSp); length(FHN)

AllMammals <- intersect(colnames(FullSTMatrix),colnames(FullRangeAdj))
AllMammals <- AllMammals[order(AllMammals)]
AbsentHosts <- FHN[which(!FHN%in%AllMammals)]

# Replacing absent names in the full ST matrix ####

NameReplace <- c(
  "Micaelamys_namaquensis",
  "Akodon_paranaensis",
  "Bos_frontalis",
  "Bos_grunniens",
  "Bubalus_arnee", # Absent
  "Capra_hircus",
  "Hexaprotodon_liberiensis",
  "Equus_burchellii",
  "Oryzomys_alfaroi" ,
  "Oryzomys_laticeps",
  "Oryzomys_megacephalus",
  "Callithrix_argentata",
  "Miniopterus_schreibersii",
  "Myotis_ricketti",
  "Oryzomys_albigularis",
  "Ovis_aries",
  "Piliocolobus_badius",
  "Piliocolobus_rufomitratus" ,
  "Lycalopex_gymnocercus" ,
  "Rhinolophus_hildebrandtii",
  "Oryzomys_angouya",
  "Mops_condylurus",
  "Chaerephon_plicatus",
  "Chaerephon_pumilus",
  "Taurotragus_oryx")

names(NameReplace) <- AbsentHosts

rownames(FullSTMatrix) <- colnames(FullSTMatrix) <- sapply(rownames(FullSTMatrix), function(a) ifelse(a%in%AbsentHosts, NameReplace[a], a))

NonEutherians <- c("Diprotodontia",
                   "Dasyuromorphia",
                   "Paucituberculata",
                   "Didelphimorphia",
                   "Microbiotheria",
                   "Peramelemorphia", 
                   "Notoryctemorphia",
                   "Monotremata")

Panth1 <- read.delim("data/PanTHERIA_1-0_WR05_Aug2008.txt") %>%
  dplyr::rename(Sp = MSW05_Binomial, hOrder = MSW05_Order, hFamily = MSW05_Family)
Panth1$Sp <- Panth1$Sp %>% str_replace(" ", "_")

NonEutherianSp <- Panth1[Panth1$hOrder%in%NonEutherians,"Sp"]

tFullSTMatrix <- 1 - (FullSTMatrix[!rownames(FullSTMatrix)%in%NonEutherianSp,!rownames(FullSTMatrix)%in%NonEutherianSp] - 
                        min(FullSTMatrix[!rownames(FullSTMatrix)%in%NonEutherianSp,!rownames(FullSTMatrix)%in%NonEutherianSp]))/
  max(FullSTMatrix[!rownames(FullSTMatrix)%in%NonEutherianSp,!rownames(FullSTMatrix)%in%NonEutherianSp])

tSTMatrix <- tFullSTMatrix

# Going Ahead ####

rownames(Hosts) = Hosts$Sp

FinalHostNames <- reduce(list(
  rownames(FullRangeAdj), 
  colnames(tFullSTMatrix),
  rownames(HostAdj)), intersect)

FinalHostNames %>% setdiff(NonEutherianSp)

FHN <- FinalHostNames; length(FHN)

UpperHosts <- # Removing diagonals, as they're uninformative
  which(upper.tri(HostAdj[FHN,FHN], diag = T))

HostMatrixdf <- data.frame(Virus = c(HostAdj[FHN, FHN]),
                           Space = c(FullRangeAdj[FHN, FHN]),
                           #SpaceA = c(RangeAdjA[FHN, FHN]),
                           #SpaceB = c(RangeAdjB[FHN, FHN]),
                           Phylo = c(tFullSTMatrix[FHN, FHN]),
                           Sp = as.character(rep(FHN, each = length(FHN))),
                           Sp2 = as.character(rep(FHN, length(FHN)))
)

HostMatrixdf$Sp <- as.character(HostMatrixdf$Sp)
HostMatrixdf$Sp2 <- as.character(HostMatrixdf$Sp2)

HostMatrixVar <- c("hOrder", "hFamily", "hDom", "hAllZACites", "hDiseaseZACites"
                   #"LongMean", "LatMean")
)

HostMatrixdf[,HostMatrixVar] <- Hosts[HostMatrixdf$Sp, HostMatrixVar]
HostMatrixdf[,paste0(HostMatrixVar,".Sp2")] <- Hosts[HostMatrixdf$Sp2, HostMatrixVar]
HostMatrixdf[HostMatrixdf$Sp == "Lynx_lynx",] <- HostMatrixdf[HostMatrixdf$Sp == "Lynx_lynx",] %>% mutate(hAllZACites = 1167, hDiseaseZACites = 115)

HostMatrixdf <- HostMatrixdf %>% mutate(
  hOrder = Hosts[HostMatrixdf$Sp,"hOrder"],
  hFamily = Hosts[HostMatrixdf$Sp,"hFamily"],
  hDom = Hosts[HostMatrixdf$Sp,"hDom"]
)

HostMatrixdf$Space0 <- ifelse(HostMatrixdf$Space == 0, "No Overlap", "Overlap")
HostMatrixdf$Cites <- log(HostMatrixdf$hAllZACites + 1)
HostMatrixdf$TotalCites <- log(HostMatrixdf$hAllZACites + HostMatrixdf$hAllZACites.Sp2 + 1)
HostMatrixdf$MinCites <- apply(HostMatrixdf[,c("hAllZACites", "hAllZACites.Sp2")],1, function(a) min(a, na.rm = T))

HostMatrixdf$DCites <- log(HostMatrixdf$hDiseaseZACites + 1)
HostMatrixdf$MinDCites <- apply(HostMatrixdf[,c("hDiseaseZACites", "hDiseaseZACites.Sp2")],1, function(a) min(a, na.rm = T))
HostMatrixdf$TotalDCites <- log(HostMatrixdf$hDiseaseZACites + HostMatrixdf$hAllZACites.Sp2 + 1)

HostMatrixdf$DomDom <- paste(HostMatrixdf$hDom, HostMatrixdf$hDom.Sp2)
HostMatrixdf$DomDom <- ifelse(HostMatrixdf$DomDom == "domestic wild", "wild domestic", HostMatrixdf$DomDom) %>%
  factor(levels = c("wild wild", "domestic domestic", "wild domestic"))

UpperHosts <- # Removing diagonals and 
  which(upper.tri(HostAdj[FHN,FHN], diag = T))

FinalHostMatrix <- HostMatrixdf[-UpperHosts,]

FinalHostMatrix$Phylo <- FinalHostMatrix$Phylo
FinalHostMatrix$MinDCites <- log(FinalHostMatrix$MinDCites + 1)
FinalHostMatrix$VirusBinary <- ifelse(FinalHostMatrix$Virus>0, 1, 0)

Remove1 <- FinalHostMatrix %>% group_by(Sp) %>% dplyr::summarise(Mean = mean(VirusBinary)) %>% slice(order(Mean)) %>% filter(Mean==0) %>% dplyr::select(Sp)
Remove2 <- FinalHostMatrix %>% group_by(Sp2) %>% dplyr::summarise(Mean = mean(VirusBinary)) %>% slice(order(Mean)) %>% filter(Mean==0) %>% dplyr::select(Sp2)

Remove3 <- which(table(c((FinalHostMatrix %>% filter(Phylo < 0.25) %>% dplyr::select(Sp, Sp2))$Sp %>% as.character(),
                         (FinalHostMatrix %>% filter(Phylo < 0.25) %>% dplyr::select(Sp, Sp2))$Sp2 %>% as.character()))>20) %>% 
  names

RemoveSp <- intersect(Remove1$Sp, Remove2$Sp2)

FinalHostMatrix <- FinalHostMatrix %>% filter(!Sp%in%RemoveSp&!Sp2%in%RemoveSp)

FinalHostMatrix$Sp <- factor(FinalHostMatrix$Sp, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))
FinalHostMatrix$Sp2 <- factor(FinalHostMatrix$Sp2, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))

FinalHostMatrix <- FinalHostMatrix %>% slice(order(Sp,Sp2))

# Let's try this a second time ####

FHN <- levels(FinalHostMatrix$Sp)

HostMatrixdf <- data.frame(Virus = c(HostAdj[FHN, FHN]),
                           Space = c(FullRangeAdj[FHN, FHN]),
                           Phylo = c(tFullSTMatrix[FHN, FHN]),
                           Sp = as.character(rep(FHN, each = length(FHN))),
                           Sp2 = as.character(rep(FHN, length(FHN)))
)

HostMatrixdf$Sp <- as.character(HostMatrixdf$Sp)
HostMatrixdf$Sp2 <- as.character(HostMatrixdf$Sp2)

HostMatrixVar <- c("hOrder", "hFamily", "hDom", "hAllZACites", "hDiseaseZACites")

HostMatrixdf[,HostMatrixVar] <- Hosts[HostMatrixdf$Sp, HostMatrixVar]
HostMatrixdf[,paste0(HostMatrixVar,".Sp2")] <- Hosts[HostMatrixdf$Sp2, HostMatrixVar]

HostMatrixdf$Cites <- log(HostMatrixdf$hAllZACites + 1)
HostMatrixdf$TotalCites <- log(HostMatrixdf$hAllZACites + HostMatrixdf$hAllZACites.Sp2 + 1)
HostMatrixdf$MinCites <- apply(HostMatrixdf[,c("hAllZACites", "hAllZACites.Sp2")],1, function(a) min(a, na.rm = T))

HostMatrixdf$DCites <- log(HostMatrixdf$hDiseaseZACites + 1)
HostMatrixdf$MinDCites <- apply(HostMatrixdf[,c("hDiseaseZACites", "hDiseaseZACites.Sp2")],1, function(a) min(a, na.rm = T))
HostMatrixdf$TotalDCites <- log(HostMatrixdf$hDiseaseZACites + HostMatrixdf$hAllZACites.Sp2 + 1)

HostMatrixdf$DomDom <- paste(HostMatrixdf$hDom, HostMatrixdf$hDom.Sp2)
HostMatrixdf$DomDom <- ifelse(HostMatrixdf$DomDom == "domestic wild", "wild domestic", HostMatrixdf$DomDom) %>%
  factor(levels = c("wild wild", "domestic domestic", "wild domestic"))

UpperHosts <- which(upper.tri(HostAdj[FHN,FHN], diag = T))

FinalHostMatrix <- HostMatrixdf[-UpperHosts,]

FinalHostMatrix$MinDCites <- log(FinalHostMatrix$MinDCites + 1)
FinalHostMatrix$VirusBinary <- ifelse(FinalHostMatrix$Virus>0, 1, 0)

FinalHostMatrix$Gz <- as.numeric(FinalHostMatrix$Space==0)

FinalHostMatrix$Sp <- factor(FinalHostMatrix$Sp, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))
FinalHostMatrix$Sp2 <- factor(FinalHostMatrix$Sp2, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))

FinalHostMatrix <- FinalHostMatrix %>% slice(order(Sp,Sp2))

# Creating viral subsets ####

# DNA and RNA viruses ####

SubResps <- c("RNA", "DNA", "Vector","NVector")

RNAViruses <- VirusTraits[VirusTraits$vDNAoRNA == "RNA","vVirusNameCorrected"] %>% intersect(rownames(M))
DNAViruses <- VirusTraits[VirusTraits$vDNAoRNA == "DNA","vVirusNameCorrected"] %>% intersect(rownames(M))

MRNA <- M[RNAViruses,]
MDNA <- M[DNAViruses,]

MRNA <- MRNA[,which(colSums(MRNA)>0)]
MDNA <- MDNA[,which(colSums(MDNA)>0)]

RNABipGraph <- graph.incidence(MRNA, weighted = T)
DNABipGraph <- graph.incidence(MDNA, weighted = T)

RNAHostGraph <- bipartite.projection(RNABipGraph)$proj2
DNAHostGraph <- bipartite.projection(DNABipGraph)$proj2

RNAHostAdj <- get.adjacency(RNAHostGraph) %>% as.matrix
DNAHostAdj <- get.adjacency(DNAHostGraph) %>% as.matrix

RNAHostdf <- RNAHostAdj %>% reshape2::melt() %>%
  dplyr::select(Var2, Var1, value) %>%
  dplyr::rename(Sp = Var2, Sp2 = Var1, RNA = value)

DNAHostdf <- DNAHostAdj %>% reshape2::melt() %>%
  dplyr::select(Var2, Var1, value) %>%
  dplyr::rename(Sp = Var2, Sp2 = Var1, DNA = value)

rownames(RNAHostdf) <- with(RNAHostdf, paste(Sp, Sp2))
rownames(DNAHostdf) <- with(DNAHostdf, paste(Sp, Sp2))

FinalHostMatrix <- FinalHostMatrix %>% left_join(RNAHostdf,
                                                 by = c("Sp","Sp2"))

FinalHostMatrix <- FinalHostMatrix %>% left_join(DNAHostdf,
                                                 by = c("Sp","Sp2"))

# Vector-Borne ####

VectorViruses <- VirusTraits %>% filter(vDNAoRNA == "RNA"&vVectorYNna == "Y") %>% 
  dplyr::select(vVirusNameCorrected) %>% 
  unlist %>% intersect(rownames(M))
MVector <- M[VectorViruses,]
MVector <- MVector[,which(colSums(MVector)>0)]
VectorBipGraph <- graph.incidence(MVector, weighted = T)
VectorHostGraph <- bipartite.projection(VectorBipGraph)$proj2
VectorHostAdj <- get.adjacency(VectorHostGraph) %>% as.matrix

VectorHostdf <- VectorHostAdj %>% reshape2::melt() %>%
  #dplyr::rename(Sp = Var2, Sp2 = Var1, Vector = value) %>%
  dplyr::select(Var2, Var1, value) %>%
  dplyr::rename(Sp = Var2, Sp2 = Var1, Vector = value)

rownames(VectorHostdf) <- with(VectorHostdf, paste(Sp, Sp2))

# Non-Vector-Borne ####

NVectorViruses <- VirusTraits %>% filter(vDNAoRNA == "RNA"&vVectorYNna == "N") %>% dplyr::select(vVirusNameCorrected) %>% unlist %>% intersect(rownames(M))
MNVector <- M[NVectorViruses,]
MNVector <- MNVector[,which(colSums(MNVector)>0)]
NVectorBipGraph <- graph.incidence(MNVector, weighted = T)
NVectorHostGraph <- bipartite.projection(NVectorBipGraph)$proj2
NVectorHostAdj <- get.adjacency(NVectorHostGraph) %>% as.matrix

NVectorHostdf <- NVectorHostAdj %>% reshape2::melt() %>%
  dplyr::select(Var2, Var1, value) %>%
  dplyr::rename(Sp = Var2, Sp2 = Var1, NVector = value)

rownames(NVectorHostdf) <- with(NVectorHostdf, paste(Sp, Sp2))

FinalHostMatrix <- FinalHostMatrix %>% left_join(VectorHostdf,
                                                 by = c("Sp","Sp2"))

FinalHostMatrix <- FinalHostMatrix %>% left_join(NVectorHostdf,
                                                 by = c("Sp","Sp2"))

FinalHostMatrix$Sp <- factor(FinalHostMatrix$Sp, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))
FinalHostMatrix$Sp2 <- factor(FinalHostMatrix$Sp2, levels = sort(union(FinalHostMatrix$Sp,FinalHostMatrix$Sp2)))

# Creating full mammal dataset ####

AllMammals <- intersect(rownames(FullSTMatrix), rownames(FullRangeAdj)) %>% setdiff(NonEutherianSp)

AllMammals <- sort(AllMammals)

AllMammalMatrix <- data.frame(
  Sp = as.character(rep(AllMammals,each = length(AllMammals))),
  Sp2 = as.character(rep(AllMammals,length(AllMammals))),
  Space = c(FullRangeAdj[AllMammals,AllMammals]),
  Phylo = c(tFullSTMatrix[AllMammals,AllMammals])
) %>% 
  mutate(Gz = as.numeric(Space==0)) %>% 
  droplevels

UpperMammals <- which(upper.tri(FullSTMatrix[AllMammals, AllMammals], diag = T))

AllMammaldf <- AllMammalMatrix[-UpperMammals,]

N = nrow(AllMammaldf)

save(FinalHostMatrix, file = "Output Files/Finaldf.Rdata")
