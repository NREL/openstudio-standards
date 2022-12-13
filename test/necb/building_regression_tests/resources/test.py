key = 'NECB2011'

NECBs = {
        "NECB2011" : "../../../../lib/openstudio-standards/standards/necb/NECB2011/data/space_types.json",
        "NECB2015" : "../../../../lib/openstudio-standards/standards/necb/NECB2015/data/space_types.json",
        "NECB2017" : "../../../../lib/openstudio-standards/standards/necb/NECB2017/data/space_types.json",
        "NECB2020" : "../../../../lib/openstudio-standards/standards/necb/NECB2020/data/space_types.json"
    }
if NECBs.get(key) is None:
    raise IndexError("Invalid template. Use one of NECB 2011, 2015, 2017 or 2020.")


for template, path in NECBs.items():
    with open(path) as file:
        print(f'great success with {template}!')


