import logging


class OpenStudioStandardsDataException(Exception):
    def __init__(self, message):
        super().__init__(message)


class OpenStudioStandardsFormDataException(OpenStudioStandardsDataException):
    def __init__(self, message):
        super().__init__(message)


def assert_(b: bool, err_msg: str):
    if not b:
        logging.getLogger("debug")
        raise OpenStudioStandardsFormDataException(err_msg)


class MissingKeyException(OpenStudioStandardsDataException):
    def __init__(self, object_name, first_key):
        message = f"{object_name} is missing {'one of the fields in: ' if isinstance(first_key, list) else ''}{first_key}"
        super().__init__(message)


def getattr_(obj, obj_name: str, first_key, *remaining_keys):
    """Gets the value inside a dictionary described by a key path or raises an expection

    Parameters
    ----------
    obj : dict
        A potentially nested dictionary of dictionaries to be searched. At each
        level along the key path, the dictionary must have an id field.
    obj_name : str
        The name for the dictionary to be searched
    first_key : str
        The first key in the path
    remaining_keys: [str]
        Any additional keys in the path

    Returns
    -------
    any
        The value stored the the given key path

    Raises
    ------
    AssertionError if the key path does not exist. The error message indicates what
    field was missing.
    """
    assert_(
        obj is not None,
        f"Object: {obj_name} provided is None, failed to search for key: {first_key}",
    )

    if first_key not in obj:
        raise MissingKeyException(obj_name, first_key)
    val = obj[first_key]

    return (
        val
        if len(remaining_keys) == 0
        else getattr_(val, first_key, remaining_keys[0], *remaining_keys[1:])
    )
