""" This module contains some auxiliary functions for the processing of
an observed dataset.
"""

# standard library
import os


def check_process(data_file, respy_obj):
    """ Check the validity of the request.
    """
    # Checks
    assert os.path.exists(data_file)
    assert respy_obj.get_attr('is_locked')

    # Finishing
    return True
