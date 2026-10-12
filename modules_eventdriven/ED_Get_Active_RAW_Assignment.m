function [Assigned_STA, RAW_End_By_Node, Active_BSS] = ...
    ED_Get_Active_RAW_Assignment(SimState, SimParams)
%ED_GET_ACTIVE_RAW_ASSIGNMENT Return contenders in active per-BSS RAW slots.

    RAW_End_By_Node = zeros(1, SimParams.N_Node);
    Assigned_STA = [];
    Active_BSS = false(1, SimParams.N_AP);

    for bss_id = 1:SimParams.N_AP
        Tab_RAW = SimState.Tab_RAW{bss_id};
        raw_idx = find(Tab_RAW(:, 3) == 1);
        if numel(raw_idx) > 1
            error('ED:MultipleActiveRAW', ...
                'Only one RAW slot may be active in each BSS.');
        end
        if isempty(raw_idx)
            continue;
        end

        Active_BSS(bss_id) = true;
        if isfield(SimState, 'ED_RAW_Assignment_Cache') && ...
           numel(SimState.ED_RAW_Assignment_Cache) >= bss_id && ...
           numel(SimState.ED_RAW_Assignment_Cache{bss_id}) >= raw_idx
            sta_ids = ...
                SimState.ED_RAW_Assignment_Cache{bss_id}{raw_idx};
        else
            Assigned = SimState.List_Assigned_STA{bss_id};
            if raw_idx > size(Assigned, 1)
                continue;
            end
            sta_ids = Assigned(raw_idx, :);
            sta_ids(sta_ids == 0) = [];
            sta_ids = unique(sta_ids, 'stable');
        end
        sta_ids = sta_ids(SimState.RAW_TX_Allowed(sta_ids));
        if isempty(sta_ids)
            continue;
        end
        if any(SimState.Node.Serving_AP(sta_ids) ~= bss_id)
            error('ED:CrossBSSRAWAssignment', ...
                'A STA was assigned outside its serving BSS.');
        end
        if any(RAW_End_By_Node(sta_ids) > 0)
            error('ED:DuplicateRAWAssignment', ...
                'A STA was assigned to multiple active RAW slots.');
        end
        RAW_End_By_Node(sta_ids) = Tab_RAW(raw_idx, 2);
        Assigned_STA = [Assigned_STA, sta_ids]; %#ok<AGROW>
    end
end
