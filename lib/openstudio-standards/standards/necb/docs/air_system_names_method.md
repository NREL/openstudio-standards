The systax used for air system names in BTAP is:  

**sys_abbr|oa|shr>?|sc>?|sh>?|ssf?|zh>?|zc>?|srf>?**

# Field "sys_abbr"  

## Description  
System type abbrevation  
## Values  
"sys_1", "sys_2", ..., "sys_6" for NECB

# Field "oa"  
## Description  
Indicates whether there is return air in the supply air  
## Values  
1. "doas": dedicated-outdoor air system
2. "mixed": system with return air in supply air  

# Field "shr>?"  
## Description  
Type of heat recovery  
## Values  
1. "none": no heat recovery  
2. "erv":  energy recovery device (sensible+latent)

# Field "sc>?"  
## Description  
System cooling equipment  
## Values  
1. "none": no cooling equipment  
2. "c-chw":  coil-chilled-water  
3. "dx":     direct-expansion  
4. "ccashp": cold-climate air-source heat pump  
5. "ashp":   air-source heat pump

# Field "sh>?"
## Description  
System heating equipment  
## Values  
1. "none": no heating equipment  
2. "c-e":    coil-electric  
3. "c-hw":   coil-hot-water  
4. "c-g":    coil-gas  
5. "ccashp": cold-climate air-source heat pump  
6. "ashp":   air-source heat pump  

# Field "ssf>?"  
## Description  
System supply fan  
## Values  
1. "cv": constant-volume  
2. "vv": variable-volume  

# Field "zh>?"
## Description  
Zone heating equipment  
## Values  
1. "none": no zone heating  
2. "tpfc": two-pipe fan coil  
3. "fpfc": four-pipe fan coil  
4. "pthp": packaged-terminal heat pump  
5. "vrf":  variable-refrigerant flow  

# Field "zc>?"  
# Desciption  
Zone cooling equipment  
## Values  
1. "none": no zone cooling  
2. "tpfc": two-pipe fan coil  
3. "fpfc": four-pipe fan coil  
4. "ptac": packaged-terminal air-conditioner 
5. "pthp": packaged-terminal heat-pump  
6. "vrf":  variable-refrigerant flow  
7. "b-e":  baseboard electric  
8. "b-hw": baseboard hot-water

# Field "srf>?"  
## Description  
System return fan  
## Values  
1. "cv": constant-volume  
2. "vv": variable-volume  

# Examples of System Names  

sys_1|doas|shr>erv|sc>dx|sh>c-e|ssf>cv|zh>b-e|zc>ptac|srf>none  
sys_1|doas|shr>erv|sc>dx|sh>c-e|ssf>cv|zh>b-hw|zc>ptac|srf>none  
sys_1|doas|shr>erv|sc>dx|sh>c-hw|ssf>cv|zh>b-e|zc>ptac|srf>none  
sys1|doas|shr>erv|sc>dx|sh>c-hw|ssf>cv|zh>b-hw|zc>ptac|srf>none  
sys1|doas|shr>erv|sc>ashp|sh>ashp|ssf>cv|zh>b-e|zc>ptac|srf>none  

sys_1|doas|shr>erv|sc>dx|sh>c-g|ssf>cv|zh>tpfc|zc>fpfc|srf>none  
sys_1|doas|shr>erv|sc>c-chw|sh>c-g|ssf>cv|zh>tpfc|zc>fpfc|srf>none  
sys_1|doas|shr>erv|sc>ashp|sh>ashp|ssf>cv|zh>tpfc|zc>fpfc|srf>none  

sys_3|mixed|shr>erv|sc>dx|sh>c-e|ssf>cv|zc>none|zh>b-e|srf>none  
sys_3|mixed|shr>erv|sc>dx|sh>c-e|ssf>cv|zc>none|zh>b-hw|srf>none  
sys_3|mixed|shr>erv|sc>dx|sh>c-hw|ssf>cv|zc>none|zh>b-e|srf>none  
sys_3|mixed|shr>erv|sc>dx|sh>c-hw|ssf>cv|zc>none|zh>b-hw|srf>none  
sys_3|mixed|shr>erv|sc>ashp|sh>ashp|ssf>cv|zc>none|zh>b-e|srf>none  

sys_4|mixed|shr>erv|sc>dx|sh>c-e|ssf>cv|zc>none|zh>b-e|srf>none  
sys_4|mixed|shr>erv|sc>dx|sh>c-e|ssf>cv|zc>none|zh>b-hw|srf>none  
sys_4|mixed|shr>erv|sc>dx|sh>c-g|ssf>cv|zc>none|zh>b-e|srf>none  
sys_4|mixed|shr>erv|sc>dx|sh>c-g|ssf>cv|zc>none|zh>b-hw|srf>none  
sys_4|mixed|shr>erv|sc>ashp|sh>ashp|ssf>cv|zc>none|zh>b-e|srf>none  

sys_5|doas|shr>erv|sc>dx|sh>c-g|ssf>cv|zc>tpfc|zh>tpfc|srf>none  
sys_5|doas|shr>erv|sc>c-chw|sh>c-g|ssf>cv|zc>tpfc|zh>tpfc|srf>none  
sys_5|doas|shr>erv|sc>ashp|sh>ashp|ssf>cv|zc>tpfc|zh>tpfc|srf>none  

sys_6|mixed|shr>erv|sc>c-chw|sh>c-e|ssf>vv|zc>none|zh>b-e|srf>vv  
sys_6|mixed|shr>erv|sc>c-chw|sh>c-e|ssf>vv|zc>none|zh>b-hw|srf>vv  
sys_6|mixed|shr>erv|sc>c-chw|sh>c-hw|ssf>vv|zc>none|zh>b-e|srf>vv  
sys_6|mixed|shr>erv|sc>c-chw|sh>c-hw|ssf>vv|zc>none|zh>b-hw|srf>vv  
sys_6|mixed|shr>erv|sc>ashp|sh>ashp|ssf>vv|zc>none|zh>b-hw|srf>vv  
