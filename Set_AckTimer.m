function [ACK_Timer] = Set_AckTimer(T_ack_Timeout, aSlotTime, Now, seqID)
% 시뮬레이션 상에서 ACK의 Time_OUT 되는 시간을 설정함
% step 1) 데이터 전송 시간 + Ack_Timeout 시간(X) --> ACK_Timeout 시간만 필요
% step 2) slot 시간으로 변환
ACK_Timer = [Now + ceil(T_ack_Timeout/aSlotTime), seqID];


end

