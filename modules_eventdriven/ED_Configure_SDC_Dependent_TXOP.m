function SimParams = ED_Configure_SDC_Dependent_TXOP( ...
    SimParams, enabled, node_ids, sdc_fraction, guard_slots, max_mpdus, ...
    boundary_mode, aggressive_multiplier)
%ED_CONFIGURE_SDC_DEPENDENT_TXOP Configure SDC-dependent EDCA TXOP bursting.
%
% The nominal RAW-slot duration is determined by SDC. The configured TXOP
% is a fraction of that duration, reduced by a small boundary guard and
% rounded down to the 32-us EDCA TXOP unit. Boundary modes are:
%   strict           - truncate at the acquisition RAW-slot boundary.
%   bounded-cross    - keep one configured TXOP budget across boundaries.
%   aggressive-cross - multiply that budget before crossing boundaries.
%   full-period-aggressive - continue through the remaining RAW period and
%                            reserve the BSS after the first successful ACK.

    if nargin < 7 || isempty(boundary_mode)
        boundary_mode = 'strict';
    end
    if nargin < 8 || isempty(aggressive_multiplier)
        aggressive_multiplier = 2;
    end
    boundary_mode = Normalize_Boundary_Mode(boundary_mode);
    Validate_Aggressive_Multiplier(aggressive_multiplier);

    SimParams.EDCA_TXOP_Enabled = false;
    SimParams.EDCA_TXOP_Mode = 'disabled';
    SimParams.EDCA_TXOP_Eligible = ...
        false(1, SimParams.N_Node);
    SimParams.EDCA_TXOP_Limit_us_By_BSS = ...
        zeros(1, SimParams.N_AP);
    SimParams.EDCA_TXOP_Limit_Slots_By_BSS = ...
        zeros(1, SimParams.N_AP);
    SimParams.EDCA_TXOP_Base_Limit_us_By_BSS = ...
        zeros(1, SimParams.N_AP);
    SimParams.EDCA_TXOP_Base_Limit_Slots_By_BSS = ...
        zeros(1, SimParams.N_AP);
    SimParams.EDCA_TXOP_Max_MPDUs = ...
        ones(1, SimParams.N_Node);
    SimParams.EDCA_TXOP_Max_MPDUs_Mode = 'disabled';
    SimParams.EDCA_TXOP_NAV_Enabled = false;
    SimParams.EDCA_TXOP_Reservation_Mode = ...
        'physical-carrier-sense-sifs';
    SimParams.EDCA_TXOP_SDC_Fraction = 0;
    SimParams.EDCA_TXOP_Guard_Slots = 0;
    SimParams.EDCA_TXOP_Quantum_us = 32;
    SimParams.EDCA_TXOP_Boundary_Mode = 'disabled';
    SimParams.EDCA_TXOP_Cross_Slot_Allowed = false;
    SimParams.EDCA_TXOP_Dynamic_Period_End = false;
    SimParams.EDCA_TXOP_Duration_Multiplier = 0;
    SimParams.EDCA_TXOP_Aggressive_Multiplier = aggressive_multiplier;

    if ~enabled
        return;
    end
    if ~isfield(SimParams, 'EDCA_Enabled') || ...
       ~SimParams.EDCA_Enabled
        error('ED:TXOPRequiresEDCA', ...
            'SDC-dependent TXOP requires EDCA to be enabled.');
    end
    if ~isscalar(sdc_fraction) || ~isfinite(sdc_fraction) || ...
       sdc_fraction <= 0 || sdc_fraction > 1
        error('ED:InvalidTXOPFraction', ...
            'CameraTXOPSDCFraction must be in (0, 1].');
    end
    if ~isscalar(guard_slots) || ~isfinite(guard_slots) || ...
       guard_slots < 0 || guard_slots ~= round(guard_slots)
        error('ED:InvalidTXOPGuard', ...
            'CameraTXOPGuardSlots must be a nonnegative integer.');
    end
    [max_mpdus, max_mpdus_mode] = Normalize_Max_MPDUs(max_mpdus);

    node_ids = unique(node_ids(:).', 'stable');
    if any(node_ids < 1 | node_ids > SimParams.N_Node | ...
           node_ids ~= round(node_ids))
        error('ED:InvalidTXOPNode', ...
            'TXOP node IDs must be valid integer node indices.');
    end

    quantum_us = SimParams.EDCA_TXOP_Quantum_us;
    nominal_raw_us = SimParams.BSS_T_RAW_Slot * 1e6;
    guard_us = guard_slots * SimParams.T_slot * 1e6;
    available_us = max(0, nominal_raw_us - guard_us);
    base_limit_us = floor( ...
        sdc_fraction * available_us / quantum_us) * quantum_us;
    base_limit_slots = floor( ...
        base_limit_us * 1e-6 / SimParams.T_slot);

    full_period = strcmp(boundary_mode, 'full-period-aggressive');
    duration_multiplier = 1;
    if strcmp(boundary_mode, 'aggressive-cross')
        duration_multiplier = aggressive_multiplier;
    elseif full_period
        % This is the maximum design budget. The runtime end is the last
        % RAW boundary of the current Beacon and therefore depends on the
        % RAW slot in which the camera obtains the TXOP.
        duration_multiplier = SimParams.N_RAW;
    end
    limit_us = base_limit_us * duration_multiplier;
    limit_slots = floor( ...
        limit_us * 1e-6 / SimParams.T_slot);

    if any(limit_slots < 1)
        error('ED:TXOPTooShort', ...
            ['The SDC-dependent TXOP becomes shorter than one simulator ' ...
             'slot. Increase SDC/fraction or reduce the guard.']);
    end

    SimParams.EDCA_TXOP_Enabled = ~isempty(node_ids);
    SimParams.EDCA_TXOP_Mode = 'sdc-fraction';
    SimParams.EDCA_TXOP_Eligible(node_ids) = true;
    SimParams.EDCA_TXOP_Limit_us_By_BSS = limit_us;
    SimParams.EDCA_TXOP_Limit_Slots_By_BSS = limit_slots;
    SimParams.EDCA_TXOP_Base_Limit_us_By_BSS = base_limit_us;
    SimParams.EDCA_TXOP_Base_Limit_Slots_By_BSS = base_limit_slots;
    SimParams.EDCA_TXOP_Max_MPDUs(node_ids) = max_mpdus;
    SimParams.EDCA_TXOP_Max_MPDUs_Mode = max_mpdus_mode;
    SimParams.EDCA_TXOP_SDC_Fraction = sdc_fraction;
    SimParams.EDCA_TXOP_Guard_Slots = guard_slots;
    SimParams.EDCA_TXOP_Boundary_Mode = boundary_mode;
    SimParams.EDCA_TXOP_Cross_Slot_Allowed = ...
        ~strcmp(boundary_mode, 'strict');
    SimParams.EDCA_TXOP_Dynamic_Period_End = full_period;
    SimParams.EDCA_TXOP_NAV_Enabled = full_period;
    if full_period
        SimParams.EDCA_TXOP_Reservation_Mode = 'full-period-nav-sifs';
    end
    SimParams.EDCA_TXOP_Duration_Multiplier = duration_multiplier;
    SimParams.EDCA_TXOP_Aggressive_Multiplier = aggressive_multiplier;
end

function mode = Normalize_Boundary_Mode(mode)
    if ~((ischar(mode) && isrow(mode)) || ...
            (isstring(mode) && isscalar(mode)))
        error('ED:InvalidTXOPBoundaryMode', ...
            'CameraTXOPBoundaryMode must be a text scalar.');
    end
    token = lower(regexprep(char(mode), '[^A-Za-z0-9]', ''));
    switch token
        case {'strict', 'rawbounded', 'boundedraw'}
            mode = 'strict';
        case {'boundedcross', 'boundedcrossslot', 'crossbounded'}
            mode = 'bounded-cross';
        case {'aggressivecross', 'aggressivecrossslot', 'crossaggressive'}
            mode = 'aggressive-cross';
        case {'fullperiodaggressive', 'fullperiod', ...
                'periodaggressive', 'aggressivefullperiod'}
            mode = 'full-period-aggressive';
        otherwise
            error('ED:InvalidTXOPBoundaryMode', ...
                ['CameraTXOPBoundaryMode must be strict, bounded-cross, ' ...
                 'aggressive-cross, or full-period-aggressive.']);
    end
end

function Validate_Aggressive_Multiplier(value)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
            value < 1 || value ~= round(value)
        error('ED:InvalidTXOPAggressiveMultiplier', ...
            'CameraTXOPAggressiveMultiplier must be a positive integer.');
    end
end

function [value, mode] = Normalize_Max_MPDUs(value)
    if (ischar(value) && isrow(value)) || ...
       (isstring(value) && isscalar(value))
        token = regexprep(char(value), '[^A-Za-z0-9]', '');
        if strcmpi(token, 'rawslotmax')
            value = inf;
            mode = 'raw-slot-max';
            return;
        end
        error('ED:InvalidTXOPMPDULimit', ...
            'CameraTXOPMaxMPDUs text value must be ''raw-slot-max''.');
    end

    if ~isnumeric(value) || ~isscalar(value) || value < 1 || ...
       (~isinf(value) && ...
        (~isfinite(value) || value ~= round(value)))
        error('ED:InvalidTXOPMPDULimit', ...
            ['CameraTXOPMaxMPDUs must be a positive integer, Inf, or ' ...
             '''raw-slot-max''.']);
    end
    if isinf(value)
        mode = 'raw-slot-max';
    else
        mode = 'fixed';
    end
end
