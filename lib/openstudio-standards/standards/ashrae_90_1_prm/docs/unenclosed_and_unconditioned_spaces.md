Unenclosed and Unconditioned Spaces

# ASHRAE 90.1-2019 PRM Reference Manual
Space types such as ventilated parking garage, attics, and crawlspaces are defined by Standard 90.1-2019 as unenclosed spaces, and for the purposes of envelope requirements, envelope components adjacent to them are treated as exterior surfaces.

# Implementation
# Key Ruby Methods
## Existing
* `model_apply_standard_constructions`: this method applies the standard construction to each surface in the model, based on the construction type currently assigned; code was added to handle surfaces adjacent to another space: if the space is conditioned, then the surface should be handled just like an exterior surface and be assigned the baseline constructions
## New
* `model_apply_constructions`: generic method used to call the PRM and non-PRM specific `model_apply_standard_constructions()` method 
