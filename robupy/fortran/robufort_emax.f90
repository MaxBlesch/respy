!*******************************************************************************
!*******************************************************************************
!
!   This delivers all functions and subroutines to the ROBUFORT library that 
!	are associated with the model under risk. 
!
!*******************************************************************************
!*******************************************************************************
MODULE robufort_emax

	!/*	external modules	    */

    USE robufort_constants

    USE robufort_auxiliary

	!/*	setup                   */

    IMPLICIT NONE

    PUBLIC

CONTAINS
!*******************************************************************************
!*******************************************************************************
SUBROUTINE simulate_emax(emax_simulated, &
                num_periods, num_draws_emax, period, k, draws_emax, & 
                payoffs_systematic, edu_max, edu_start, periods_emax, & 
                states_all, mapping_state_idx, delta, shocks_cholesky, & 
                shocks_mean)

    !/* external objects    */

    REAL(our_dble), INTENT(OUT)     :: emax_simulated

    INTEGER(our_int), INTENT(IN)    :: mapping_state_idx(:, :, :, :, :)
    INTEGER(our_int), INTENT(IN)    :: states_all(:, :, :)
    INTEGER(our_int), INTENT(IN)    :: num_draws_emax
    INTEGER(our_int), INTENT(IN)    :: num_periods
    INTEGER(our_int), INTENT(IN)    :: edu_start
    INTEGER(our_int), INTENT(IN)    :: edu_max
    INTEGER(our_int), INTENT(IN)    :: period
    INTEGER(our_int), INTENT(IN)    :: k

    REAL(our_dble), INTENT(IN)      :: payoffs_systematic(:)
    REAL(our_dble), INTENT(IN)      :: shocks_cholesky(:, :)
    REAL(our_dble), INTENT(IN)      :: periods_emax(:, :)
    REAL(our_dble), INTENT(IN)      :: draws_emax(:, :)
    REAL(our_dble), INTENT(IN)      :: shocks_mean(:)

    REAL(our_dble), INTENT(IN)      :: delta

    !/* internals objects    */

    INTEGER(our_int)                :: i

    REAL(our_dble)                  :: draws_emax_transformed(num_draws_emax, 4)
    REAL(our_dble)                  :: total_payoffs(4)
    REAL(our_dble)                  :: draws(4)
    REAL(our_dble)                  :: maximum

!-------------------------------------------------------------------------------
! Algorithm
!-------------------------------------------------------------------------------

    ! Initialize containers
    emax_simulated = zero_dble

    ! Transfer draws to relevant distribution
    DO i = 1, num_draws_emax
        draws_emax_transformed(i:i, :) = &
            TRANSPOSE(MATMUL(shocks_cholesky, TRANSPOSE(draws_emax(i:i, :)))) 
    END DO
    
    draws_emax_transformed(:, :2) = draws_emax_transformed(:, :2) + &
        SPREAD(shocks_mean, 1, num_draws_emax)

    DO i = 1, 2
        draws_emax_transformed(:, i) = &
            EXP(draws_emax_transformed(:, i))
    END DO


    ! Iterate over Monte Carlo draws
    DO i = 1, num_draws_emax

        ! Select draws for this draw
        draws = draws_emax_transformed(i, :)

        ! Calculate total value
        CALL get_total_value(total_payoffs, &
                period, num_periods, delta, payoffs_systematic, draws, &
                edu_max, edu_start, mapping_state_idx, periods_emax, k, & 
                states_all)
   
        ! Determine optimal choice
        maximum = MAXVAL(total_payoffs)

        ! Recording expected future value
        emax_simulated = emax_simulated + maximum

    END DO

    ! Scaling
    emax_simulated = emax_simulated / num_draws_emax

END SUBROUTINE
!*******************************************************************************
!*******************************************************************************
SUBROUTINE get_total_value(total_payoffs, &
                period, num_periods, delta, payoffs_systematic, draws, & 
                edu_max, edu_start, mapping_state_idx, periods_emax, k, & 
                states_all)

    !   Development Note:
    !   
    !       The VECTORIZATION supports the inlining and vectorization
    !       preparations in the build process.

    !/* external objects        */

    REAL(our_dble), INTENT(OUT)     :: total_payoffs(:)

    INTEGER(our_int), INTENT(IN)    :: mapping_state_idx(:, :, :, :, :)
    INTEGER(our_int), INTENT(IN)    :: states_all(:, :, :)
    INTEGER(our_int), INTENT(IN)    :: num_periods
    INTEGER(our_int), INTENT(IN)    :: edu_start
    INTEGER(our_int), INTENT(IN)    :: edu_max
    INTEGER(our_int), INTENT(IN)    :: period
    INTEGER(our_int), INTENT(IN)    :: k

    REAL(our_dble), INTENT(IN)      :: payoffs_systematic(:)
    REAL(our_dble), INTENT(IN)      :: periods_emax(:, :)
    REAL(our_dble), INTENT(IN)      :: draws(:)
    REAL(our_dble), INTENT(IN)      :: delta

    !/* internal objects        */

    REAL(our_dble)                  :: payoffs_future(4)
    REAL(our_dble)                  :: payoffs_ex_post(4)

    
!-------------------------------------------------------------------------------
! Algorithm
!-------------------------------------------------------------------------------
    
    ! Initialize containers
    payoffs_ex_post = zero_dble

    ! Calculate ex post payoffs
    payoffs_ex_post(1) = payoffs_systematic(1) * draws(1)
    payoffs_ex_post(2) = payoffs_systematic(2) * draws(2)
    payoffs_ex_post(3) = payoffs_systematic(3) + draws(3)
    payoffs_ex_post(4) = payoffs_systematic(4) + draws(4)

    ! Get future values
    IF (period .NE. (num_periods - one_int)) THEN
        CALL get_future_payoffs(payoffs_future, edu_max, edu_start, &
                mapping_state_idx, period,  periods_emax, k, states_all)
        ELSE
            payoffs_future = zero_dble
    END IF

    ! Calculate total utilities
    total_payoffs = payoffs_ex_post + delta * payoffs_future

    ! This is required to ensure that the agent does not choose any
    ! inadmissible states.
    IF (payoffs_future(3) == -HUGE_FLOAT) THEN
        total_payoffs(3) = -HUGE_FLOAT
    END IF
    
END SUBROUTINE
!*******************************************************************************
!*******************************************************************************
SUBROUTINE get_future_payoffs(payoffs_future, edu_max, edu_start, &
                mapping_state_idx, period, periods_emax, k, states_all)

    !/* external objects        */

    REAL(our_dble), INTENT(OUT)     :: payoffs_future(:)

    INTEGER(our_int), INTENT(IN)    :: mapping_state_idx(:, :, :, :, :)
    INTEGER(our_int), INTENT(IN)    :: states_all(:, :, :)
    INTEGER(our_int), INTENT(IN)    :: edu_start
    INTEGER(our_int), INTENT(IN)    :: edu_max
    INTEGER(our_int), INTENT(IN)    :: period
    INTEGER(our_int), INTENT(IN)    :: k

    REAL(our_dble), INTENT(IN)      :: periods_emax(:, :)

    !/* internals objects       */

    INTEGER(our_int)                :: edu_lagged
    INTEGER(our_int)                :: future_idx
    INTEGER(our_int)    			:: exp_a
    INTEGER(our_int)    			:: exp_b
    INTEGER(our_int)    			:: edu
    
!-------------------------------------------------------------------------------
! Algorithm
!-------------------------------------------------------------------------------

    ! Distribute state space
    exp_a = states_all(period + 1, k + 1, 1)
    exp_b = states_all(period + 1, k + 1, 2)
    edu = states_all(period + 1, k + 1, 3)
    edu_lagged = states_all(period + 1, k + 1, 4)

	! Working in occupation A
    future_idx = mapping_state_idx(period + 1 + 1, exp_a + 1 + 1, & 
                    exp_b + 1, edu + 1, 1)
    payoffs_future(1) = periods_emax(period + 1 + 1, future_idx + 1)

	!Working in occupation B
    future_idx = mapping_state_idx(period + 1 + 1, exp_a + 1, &
                    exp_b + 1 + 1, edu + 1, 1)
    payoffs_future(2) = periods_emax(period + 1 + 1, future_idx + 1)

	! Increasing schooling. Note that adding an additional year
	! of schooling is only possible for those that have strictly
	! less than the maximum level of additional education allowed.
    IF (edu < edu_max - edu_start) THEN
        future_idx = mapping_state_idx(period + 1 + 1, exp_a + 1, &
                        exp_b + 1, edu + 1 + 1, 2)
        payoffs_future(3) = periods_emax(period + 1 + 1, future_idx + 1)
    ELSE
        payoffs_future(3) = -HUGE_FLOAT
    END IF

	! Staying at home
    future_idx = mapping_state_idx(period + 1 + 1, exp_a + 1, & 
                    exp_b + 1, edu + 1, 1)
    payoffs_future(4) = periods_emax(period + 1 + 1, future_idx + 1)

END SUBROUTINE
!*******************************************************************************
!*******************************************************************************
SUBROUTINE get_exogenous_variables(independent_variables, maxe, period, & 
                num_periods, num_states, delta, periods_payoffs_systematic, & 
                shifts, edu_max, edu_start, mapping_state_idx, periods_emax, & 
                states_all)

    !/* external objects        */

    REAL(our_dble), INTENT(OUT)         :: independent_variables(:, :)
    REAL(our_dble), INTENT(OUT)         :: maxe(:)

    REAL(our_dble), INTENT(IN)          :: periods_payoffs_systematic(:, :, :)
    REAL(our_dble), INTENT(IN)          :: periods_emax(:, :)
    REAL(our_dble), INTENT(IN)          :: shifts(:)
    REAL(our_dble), INTENT(IN)          :: delta

    INTEGER(our_int), INTENT(IN)        :: mapping_state_idx(:, :, :, :, :)    
    INTEGER(our_int), INTENT(IN)        :: states_all(:, :, :)    
    INTEGER(our_int), INTENT(IN)        :: num_periods
    INTEGER(our_int), INTENT(IN)        :: num_states
    INTEGER(our_int), INTENT(IN)        :: edu_start
    INTEGER(our_int), INTENT(IN)        :: edu_max
    INTEGER(our_int), INTENT(IN)        :: period


    !/* internal objects        */

    REAL(our_dble)                      :: payoffs_systematic(4)
    REAL(our_dble)                      :: expected_values(4)
    REAL(our_dble)                      :: diff(4)

    INTEGER(our_int)                    :: k

    LOGICAL                             :: is_inadmissible

!-------------------------------------------------------------------------------
! Algorithm
!-------------------------------------------------------------------------------

    ! Construct exogenous variable for all states
    DO k = 0, (num_states - 1)

        payoffs_systematic = periods_payoffs_systematic(period + 1, k + 1, :)

        CALL get_total_value(expected_values, &
                period, num_periods, delta, payoffs_systematic, shifts, &
                edu_max, edu_start, mapping_state_idx, periods_emax, k, &
                states_all)

        ! Treatment of inadmissible states, which will show up in the regression 
        ! in some way
        is_inadmissible = (expected_values(3) == -HUGE_FLOAT)

        IF (is_inadmissible) THEN

            expected_values(3) = interpolation_inadmissible_states

        END IF

        ! Implement level shifts
        maxe(k + 1) = MAXVAL(expected_values)

        diff = maxe(k + 1) - expected_values

        ! Construct regressors
        independent_variables(k + 1, 1:4) = diff
        independent_variables(k + 1, 5:8) = DSQRT(diff)

    END DO

    ! Add intercept to set of independent variables
    independent_variables(:, 9) = one_dble

END SUBROUTINE
!*******************************************************************************
!*******************************************************************************
END MODULE