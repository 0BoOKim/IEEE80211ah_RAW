function SimParams = Build_BSS_RAW_Config(SimParams)
%BUILD_BSS_RAW_CONFIG Build per-BSS RAW timing configuration vectors.
%
% Backward compatibility:
% - Existing scalar fields Opt_N_RAW and Opt_Slot_Duration_Count remain valid.
% - By default, every BSS receives the same RAW configuration.
% - To customize per BSS, set BSS_Opt_N_RAW and/or
%   BSS_Opt_Slot_Duration_Count to 1-by-N_AP vectors, then call this helper.

    if ~isfield(SimParams, 'On_RAW') || ~SimParams.On_RAW
        return;
    end

    n_ap = SimParams.N_AP;

    if ~isfield(SimParams, 'BSS_RAW_Config_Mode') || isempty(SimParams.BSS_RAW_Config_Mode)
        SimParams.BSS_RAW_Config_Mode = 'uniform';
    end

    if ~isfield(SimParams, 'BSS_Opt_N_RAW') || isempty(SimParams.BSS_Opt_N_RAW)
        SimParams.BSS_Opt_N_RAW = SimParams.Opt_N_RAW;
    end

    if ~isfield(SimParams, 'BSS_Opt_Slot_Duration_Count') || isempty(SimParams.BSS_Opt_Slot_Duration_Count)
        SimParams.BSS_Opt_Slot_Duration_Count = SimParams.Opt_Slot_Duration_Count;
    end

    bss_n_raw = Expand_BSS_Vector(SimParams.BSS_Opt_N_RAW, n_ap, 'BSS_Opt_N_RAW');
    bss_sdc = Expand_BSS_Vector(SimParams.BSS_Opt_Slot_Duration_Count, n_ap, 'BSS_Opt_Slot_Duration_Count');

    if any(abs(bss_n_raw - round(bss_n_raw)) > eps) || any(bss_n_raw < 1)
        error('BSS_Opt_N_RAW must contain positive integer values.');
    end

    if any(abs(bss_sdc - round(bss_sdc)) > eps) || any(bss_sdc < 0)
        error('BSS_Opt_Slot_Duration_Count must contain nonnegative integer values.');
    end

    SimParams.BSS_N_RAW = round(bss_n_raw);
    SimParams.BSS_Opt_Slot_Duration_Count = round(bss_sdc);
    SimParams.BSS_T_RAW_Slot = 500*10^-6 + SimParams.BSS_Opt_Slot_Duration_Count*120*10^-6;
    SimParams.BSS_T_RAW_Slot_in_Slot = ceil(SimParams.BSS_T_RAW_Slot/SimParams.T_slot);
    SimParams.BSS_Beacon_Interval = SimParams.BSS_T_RAW_Slot_in_Slot .* SimParams.BSS_N_RAW;
    SimParams.BSS_RAW_Cycle_Interval = SimParams.BSS_Beacon_Interval + SimParams.BSS_N_RAW;
end

function v = Expand_BSS_Vector(v, n_ap, field_name)
    v = v(:).';
    if isscalar(v)
        v = repmat(v, 1, n_ap);
    end

    if length(v) ~= n_ap
        error('%s must be scalar or a 1-by-N_AP vector.', field_name);
    end

    if any(~isfinite(v))
        error('%s must contain finite values.', field_name);
    end
end
