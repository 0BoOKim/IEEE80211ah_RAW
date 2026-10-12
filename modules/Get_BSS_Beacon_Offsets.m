function offsets = Get_BSS_Beacon_Offsets(SimParams)
%GET_BSS_BEACON_OFFSETS Return per-BSS Beacon/RAW timing offsets in slots.

    if ~isfield(SimParams, 'N_AP') || SimParams.N_AP < 1
        offsets = [];
        return;
    end

    if ~isfield(SimParams, 'BSS_Beacon_Offset_Mode') || isempty(SimParams.BSS_Beacon_Offset_Mode)
        mode = 'sync';
    else
        mode = SimParams.BSS_Beacon_Offset_Mode;
    end

    if isstring(mode)
        mode = char(mode);
    end

    switch lower(mode)
        case {'sync', 'synchronous'}
            offsets = zeros(1, SimParams.N_AP);

        case {'uniform', 'uniform-offset', 'staggered'}
            if isfield(SimParams, 'BSS_RAW_Cycle_Interval') && ~isempty(SimParams.BSS_RAW_Cycle_Interval)
                raw_cycle_in_slots = max(SimParams.BSS_RAW_Cycle_Interval);
            else
                raw_cycle_in_slots = SimParams.Beacon_Interval + SimParams.N_RAW;
            end
            offsets = floor((0:SimParams.N_AP-1) * raw_cycle_in_slots / SimParams.N_AP);

        case {'custom', 'manual'}
            if ~isfield(SimParams, 'BSS_Beacon_Offset')
                error('BSS_Beacon_Offset must be defined when BSS_Beacon_Offset_Mode is custom.');
            end

            offsets = SimParams.BSS_Beacon_Offset(:).';
            if length(offsets) ~= SimParams.N_AP
                error('BSS_Beacon_Offset length must match N_AP.');
            end

        otherwise
            error('Unsupported BSS_Beacon_Offset_Mode: %s', mode);
    end

    if any(~isfinite(offsets)) || any(offsets < 0) || any(abs(offsets - round(offsets)) > eps)
        error('BSS Beacon/RAW offsets must be finite nonnegative integer slot counts.');
    end

    offsets = round(offsets);
end

