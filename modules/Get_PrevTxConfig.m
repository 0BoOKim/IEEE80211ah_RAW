function [TxProb, TxWeight] = Get_PrevTxConfig(Node_ID,Tab_PrevTxConfig)

    TxProb = Tab_PrevTxConfig(Node_ID, 1);
    TxWeight = Tab_PrevTxConfig(Node_ID, 2);

end

