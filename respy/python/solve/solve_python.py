import respy.python.shared.shared_constants as shared_constants
from respy.python.solve.solve_auxiliary import pyth_calculate_rewards_systematic
from respy.python.solve.solve_auxiliary import pyth_create_state_space
from respy.python.solve.solve_auxiliary import pyth_backward_induction
from respy.python.record.record_solution import record_solution_progress


def pyth_solve(coeffs_a, coeffs_b, coeffs_edu, coeffs_home, shocks_cholesky,
        is_interpolated, num_points_interp, num_draws_emax, num_periods,
        is_myopic, edu_start, is_debug, edu_max, min_idx, delta,
        periods_draws_emax, is_ambiguity, measure, level, optimizer_options):
    """ Solving the model using pure PYTHON code.
    """
    # Creating the state space of the model and collect the results in the
    # package class.
    record_solution_progress(1)

    # Create state space
    states_all, states_number_period, mapping_state_idx, max_states_period = \
        pyth_create_state_space(num_periods, edu_start, edu_max, min_idx)

    # Cutting to size
    states_all = states_all[:, :max(states_number_period), :]

    record_solution_progress(-1)

    # Calculate systematic rewards which are later used in the backward
    # induction procedure. These are calculated without any reference
    # to the alternative shock distributions.
    record_solution_progress(2)

    # Calculate all systematic rewards
    periods_rewards_systematic = pyth_calculate_rewards_systematic(num_periods,
        states_number_period, states_all, edu_start, coeffs_a, coeffs_b,
        coeffs_edu, coeffs_home, max_states_period)

    record_solution_progress(-1)

    # Backward iteration procedure. There is a PYTHON and FORTRAN
    # implementation available. If agents are myopic, the backward induction
    # procedure is not called upon.
    record_solution_progress(3)

    periods_emax = pyth_backward_induction(num_periods,
        is_myopic, max_states_period, periods_draws_emax, num_draws_emax,
        states_number_period, periods_rewards_systematic, edu_max, edu_start,
        mapping_state_idx, states_all, delta, is_debug, is_interpolated,
        num_points_interp, shocks_cholesky, is_ambiguity, measure, level,
        optimizer_options, True)

    record_solution_progress(-1)

    # Collect return arguments in tuple
    args = (periods_rewards_systematic, states_number_period,
        mapping_state_idx, periods_emax, states_all)

    # Finishing
    return args
