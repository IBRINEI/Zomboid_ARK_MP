local Model = BunkerCampaignToxicMP.ContaminationModel

assert(Model.deposit(0, 2, 5) == 10, "zone deposition must scale with elapsed time")
assert(Model.deposit(99, 2, 5) == 100, "surface contamination must be capped")
assert(Model.contact(0, 80, 0.25) == 20, "contact must move contamination toward the source")
assert(Model.contact(50, 20, 0.5) == 50, "cleaner gear must not contaminate a dirtier body")
assert(Model.clean(80, 0.75) == 20, "decontamination must remove the configured fraction")
assert(Model.classify(0) == "clean", "zero contamination must be clean")
assert(Model.classify(20) == "dirty", "mid-level contamination must be dirty")
assert(Model.classify(80) == "dangerous", "high contamination must be dangerous")

print("BunkerCampaignToxicMP contamination model tests passed")
