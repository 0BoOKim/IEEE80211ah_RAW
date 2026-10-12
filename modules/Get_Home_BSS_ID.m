function BSS_ID = Get_Home_BSS_ID(Local_STA_ID, N_BSS)
    BSS_ID = mod(Local_STA_ID - 1, N_BSS) + 1;
end
