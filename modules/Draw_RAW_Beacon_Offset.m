function [n_offset, fcs_lower16, next_prng_state] = ...
    Draw_RAW_Beacon_Offset(SimParams, n_raw, prng_state)
%DRAW_RAW_BEACON_OFFSET Derive the per-Beacon RAW offset.
% The default model replaces the Beacon FCS lower 16 bits with a dedicated
% 16-bit pseudo-random sample and applies N_offset = mod(sample, N_RAW).

    if ~isscalar(n_raw) || ~isfinite(n_raw) || ...
            n_raw < 1 || n_raw ~= round(n_raw)
        error('N_RAW must be a positive integer.');
    end

    mode = 'beacon-fcs16';
    if isfield(SimParams, 'RAW_Offset_Mode') && ...
            ~isempty(SimParams.RAW_Offset_Mode)
        mode = lower(strtrim(char(SimParams.RAW_Offset_Mode)));
    end

    switch mode
        case 'beacon-fcs16'
            if isempty(prng_state) || ~isscalar(prng_state)
                error('RAW offset PRNG state is not initialized.');
            end
            next_prng_state = Xorshift32(uint32(prng_state));
            % Use the PRNG's upper 16 bits to avoid low-bit correlation when
            % a small power-of-two N_RAW is used by the modulo operation.
            fcs_lower16 = double(bitshift(next_prng_state, -16));
            n_offset = mod(fcs_lower16, n_raw);

        case 'fixed'
            fixed_offset = 0;
            if isfield(SimParams, 'N_offset') && ...
                    ~isempty(SimParams.N_offset)
                fixed_offset = SimParams.N_offset;
            end
            if ~isscalar(fixed_offset) || ~isfinite(fixed_offset) || ...
                    fixed_offset ~= round(fixed_offset)
                error('N_offset must be a finite integer in fixed mode.');
            end
            n_offset = mod(fixed_offset, n_raw);
            fcs_lower16 = NaN;
            next_prng_state = uint32(prng_state);

        otherwise
            error('Unsupported RAW_Offset_Mode: %s', mode);
    end
end

function x = Xorshift32(x)
    if x == 0
        x = uint32(2463534242);
    end
    x = bitxor(x, bitshift(x, 13));
    x = bitxor(x, bitshift(x, -17));
    x = bitxor(x, bitshift(x, 5));
    if x == 0
        x = uint32(2463534242);
    end
end
