function SimState = ED_Init_TXOP_State(SimState, SimParams)
%ED_INIT_TXOP_STATE Initialize per-STA EDCA TXOP runtime state and stats.

    n = SimParams.N_Node;
    SimState.ED_TXOP = struct();
    SimState.ED_TXOP.Active = false(1, n);
    SimState.ED_TXOP.StartSlot = -ones(1, n);
    SimState.ED_TXOP.EndSlot = -ones(1, n);
    SimState.ED_TXOP.RAWEndSlot = -ones(1, n);
    SimState.ED_TXOP.AcquisitionRAWEndSlot = -ones(1, n);
    SimState.ED_TXOP.PeriodEndSlot = -ones(1, n);
    SimState.ED_TXOP.NextDataSlot = inf(1, n);
    SimState.ED_TXOP.MPDUsInCurrent = zeros(1, n);
    SimState.ED_TXOP.ReservationEstablished = false(1, n);
    SimState.ED_TXOP.Acquisitions = zeros(1, n);
    SimState.ED_TXOP.ContinuationAttempts = zeros(1, n);
    SimState.ED_TXOP.AcknowledgedMPDUs = zeros(1, n);
    SimState.ED_TXOP.Completed = zeros(1, n);
    SimState.ED_TXOP.Aborted = zeros(1, n);
    SimState.ED_TXOP.LimitStops = zeros(1, n);
    SimState.ED_TXOP.CrossSlotExchanges = zeros(1, n);
    SimState.ED_TXOP.CrossSlotExchangeOverrunSlots = zeros(1, n);
    SimState.ED_TXOP.PeriodBoundaryViolations = zeros(1, n);
    SimState.ED_TXOP.PeriodBoundaryOverrunSlots = zeros(1, n);
    SimState.ED_TXOP.ReservationForeignStarts = zeros(1, n);
    SimState.ED_TXOP.ReservationForeignDataStarts = zeros(1, n);
    SimState.ED_TXOP.ReservationForeignACKStarts = zeros(1, n);
    SimState.ED_TXOP.ReservationSensedDataStarts = zeros(1, n);
    SimState.ED_TXOP.ReservationHiddenDataStarts = zeros(1, n);
    SimState.ED_TXOP.ReservationCollidedDataStarts = zeros(1, n);
end
