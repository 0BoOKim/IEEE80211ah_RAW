function SimParams = ED_Apply_EDCA_Access_Categories( ...
    SimParams, enabled, profiles, alarm_ac, camera_ac)
%ED_APPLY_EDCA_ACCESS_CATEGORIES Apply class-specific AIFS/CW parameters.
%
% RAW determines which STAs may contend. Among eligible STAs, this helper
% gives camera STAs AC_VI contention parameters and alarm STAs AC_BE
% parameters. The event-driven MAC already consumes the resulting per-node
% AIFSN, CW_min, and CW_max vectors.

    SimParams.EDCA_Enabled = logical(enabled);
    SimParams.EDCA_Alarm_Access_Category = 'DCF';
    SimParams.EDCA_Camera_Access_Category = 'DCF';
    SimParams.EDCA_TXOP_Enabled = false;
    SimParams.EDCA_Profile_TXOP_Limit_us = ...
        zeros(1, SimParams.N_Node);

    if ~enabled
        return;
    end

    alarm_ac = char(string(alarm_ac));
    camera_ac = char(string(camera_ac));
    alarm_profile = Get_Profile(profiles, alarm_ac);
    camera_profile = Get_Profile(profiles, camera_ac);
    Validate_Profile(alarm_profile, alarm_ac);
    Validate_Profile(camera_profile, camera_ac);
    if alarm_profile.TXOPLimit_us ~= 0 || ...
       camera_profile.TXOPLimit_us ~= 0
        error('ED:UseSDCDependentTXOPConfig', ...
            ['Keep EDCA profile TXOPLimit_us at zero and configure ' ...
             'camera TXOP through EnableTXOP and the SDC-dependent ' ...
             'TXOP fields.']);
    end

    alarm_ids = SimParams.idx_STA_Type1;
    camera_ids = SimParams.idx_Camera_STA;
    other_sta = setdiff(SimParams.idx_STA, camera_ids, 'stable');

    % Unclassified/background STAs inherit AC_BE. Alarm STAs are included
    % explicitly to make the requested traffic-class mapping unambiguous.
    SimParams = Apply_Profile( ...
        SimParams, other_sta, alarm_profile);
    SimParams = Apply_Profile( ...
        SimParams, alarm_ids, alarm_profile);
    SimParams = Apply_Profile( ...
        SimParams, camera_ids, camera_profile);

    SimParams.EDCA_Alarm_Access_Category = alarm_ac;
    SimParams.EDCA_Camera_Access_Category = camera_ac;
    SimParams.EDCA_Alarm_AIFSN = alarm_profile.AIFSN;
    SimParams.EDCA_Camera_AIFSN = camera_profile.AIFSN;
    SimParams.EDCA_Alarm_AIFS_Slots = AIFS_Slots( ...
        SimParams, alarm_profile.AIFSN);
    SimParams.EDCA_Camera_AIFS_Slots = AIFS_Slots( ...
        SimParams, camera_profile.AIFSN);
    SimParams.EDCA_Alarm_CWmin = alarm_profile.CWmin;
    SimParams.EDCA_Alarm_CWmax = alarm_profile.CWmax;
    SimParams.EDCA_Camera_CWmin = camera_profile.CWmin;
    SimParams.EDCA_Camera_CWmax = camera_profile.CWmax;
    SimParams.EDCA_Alarm_Profile_TXOP_Limit_us = ...
        alarm_profile.TXOPLimit_us;
    SimParams.EDCA_Camera_Profile_TXOP_Limit_us = ...
        camera_profile.TXOPLimit_us;
end

function profile = Get_Profile(profiles, access_category)
    if ~isstruct(profiles) || ~isfield(profiles, access_category)
        error('ED:UnknownAccessCategory', ...
            'No EDCA profile is defined for %s.', access_category);
    end
    profile = profiles.(access_category);
end

function Validate_Profile(profile, access_category)
    required = {'AIFSN', 'CWmin', 'CWmax', 'TXOPLimit_us'};
    if ~isstruct(profile) || ~all(isfield(profile, required))
        error('ED:InvalidEDCAProfile', ...
            'EDCA profile %s is missing required fields.', access_category);
    end
    values = [profile.AIFSN, profile.CWmin, ...
        profile.CWmax, profile.TXOPLimit_us];
    if any(~isfinite(values)) || any(values < 0) || ...
       any(values ~= round(values)) || profile.AIFSN < 1 || ...
       profile.CWmax < profile.CWmin
        error('ED:InvalidEDCAProfile', ...
            'EDCA profile %s contains invalid parameter values.', ...
            access_category);
    end
end

function SimParams = Apply_Profile(SimParams, node_ids, profile)
    if isempty(node_ids)
        return;
    end
    SimParams.AIFSN(node_ids) = AIFS_Slots( ...
        SimParams, profile.AIFSN);
    SimParams.CW_min(node_ids) = profile.CWmin + 1;
    SimParams.CW_max(node_ids) = profile.CWmax + 1;
    SimParams.EDCA_Profile_TXOP_Limit_us(node_ids) = ...
        profile.TXOPLimit_us;
end

function slots = AIFS_Slots(SimParams, aifsn)
    slots = ceil((SimParams.T_sifs + ...
        aifsn * SimParams.T_slot) / SimParams.T_slot);
end
