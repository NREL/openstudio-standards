# BC Energy Step Code Performance Indicators
The **bc_energy_step_code_performance_indicators** method in btap_data.rb (see /lib/openstudio-standards/standards/necb/common/btap_data.rb) 
calculates TEDI and MEUI as per BC Energy Step Code.
Refer to the below reference for the TEDI and MEUI definitions:
* BC Energy Step CodeHandbook for Building Officials: Part 9 Residential Buildings (2019). Available at: http://energystepcode.ca/app/uploads/sites/257/2019/10/BOABC-BCEnergyStepCodeHandbook-2019-10-01.pdf.

# Assumptions
The below assumption has been made:
* For the calculation of TEDI, it has been assumed that baseboards and heating coils are the only heating terminals 
in a building model's thermal zones as this is the case for the current BTAP archetypes.