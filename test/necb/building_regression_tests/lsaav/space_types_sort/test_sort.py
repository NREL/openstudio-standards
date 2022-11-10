import random

def shuffle_list(input_list):
    shuffled_list = list(input_list)
    random.seed(132625)
    random.shuffle(shuffled_list)
    return shuffled_list

def sort_list(input_list: list, itr_diff: int, itr_size: int, itr_n: int):
    """

    :param input_list: list of elements to be iterated through in different groups
    :param itr_size: size of iteration group
    :param itr_diff: size of iteration change (has to be smaller than group_size)
    :param itr_n: amount of iterations to go through. Default should be a function of input_list length.
    :return: 2D matrix of all iterations.

    sort_list(<params>)
        Should probably be called iteration_groups_generate. It generates a 2D list (matrix) based on the input list.
        Every row of the matrix is an iteration, that is of size its_size. Every iteration is a random subset of
        the input_list. Every next iteration only differs from the previous by group_size elements. The final output
        should have iterated through all of the input_list elements.
    """
    shuffled_list = shuffle_list(input_list)

    output_matrix = []
    current_itr = []

    # First iteration
    for i in range(itr_size):
        current_itr.append(shuffled_list.pop())
    output_matrix.append(current_itr)

    # Rest of iterations
    for i in range(itr_n):
        random.shuffle(current_itr)
        for j in range(itr_diff):
            current_itr.pop()
        for k in range(itr_diff):
            try:
                current_itr.append(shuffled_list.pop())
            except IndexError:
                shuffled_list = shuffle_list(input_list)
                current_itr.append(shuffled_list.pop())

        current_itr.sort()
        output_matrix.append(list(current_itr))

    return output_matrix




if __name__ == '__main__':
    test = []
    for i in range(4):
        for j in ['a','b']:
            test.append(f'st{i}-{j}')

    for i in range(8):
        test.append(f'st{i+8}')
    print(test)
    for i in sort_list(test, 2, 5, 10):
        print(i)
