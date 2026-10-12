function Assigned = Build_Fixed_RAW_Assignment(sta_ids, n_raw, offset)
%BUILD_FIXED_RAW_ASSIGNMENT Map every associated STA by ID and Beacon offset.

    sta_ids = sta_ids(:).';
    Assigned = zeros(n_raw, max(numel(sta_ids), 1));
    for k = 1:numel(sta_ids)
        raw_idx = mod(sta_ids(k) + offset, n_raw) + 1;
        Assigned(raw_idx, k) = sta_ids(k);
    end
end
