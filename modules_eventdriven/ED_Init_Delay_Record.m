function DelayRecord = ED_Init_Delay_Record(initial_capacity)
%ED_INIT_DELAY_RECORD Initialize a geometrically growing delay log.

    if nargin < 1 || isempty(initial_capacity)
        initial_capacity = 64;
    end
    DelayRecord.delay = zeros(0, 3);
    DelayRecord.ED_Data = zeros(max(1, round(initial_capacity)), 3);
    DelayRecord.ED_Count = 0;
end
