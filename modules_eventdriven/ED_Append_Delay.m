function DelayRecord = ED_Append_Delay( ...
    DelayRecord, generated_slot, completed_slot)
%ED_APPEND_DELAY Append a delay record without growing on every success.

    next_row = DelayRecord.ED_Count + 1;
    if next_row > size(DelayRecord.ED_Data, 1)
        capacity = size(DelayRecord.ED_Data, 1);
        DelayRecord.ED_Data(2 * capacity, 3) = 0;
    end
    DelayRecord.ED_Data(next_row, :) = [ ...
        generated_slot, completed_slot, completed_slot - generated_slot];
    DelayRecord.ED_Count = next_row;
end
