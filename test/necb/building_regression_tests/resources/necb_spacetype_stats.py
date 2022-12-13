import spacetype_test_sets_generator as helper
import json
import csv

def get_necb_spacetype_stats(output_path = None):
    templates = [
        'NECB2011',
        'NECB2015',
        'NECB2017',
        'NECB2020'
    ]
    info_matrix = []
    info_matrix.append(['Template', '# Space functions', '# Whole buildings'])
    for template in templates:
        names = helper.parse_spacetype_names(template)
        with open(f'./temp/all-names-{template}-test.json') as file:
            data = json.load(file)
            row = [f'{template}', f'{len(names)}', f'{len(data) - 1}']
            info_matrix.append(row)

    if output_path is not None:
        with open(output_path, 'w+') as table:
            writer = csv.writer(table, delimiter=',')
            writer.writerows(info_matrix)

    return info_matrix

if __name__ == '__main__':
    get_necb_spacetype_stats('./temp/necb_spacetype_stats.csv')
