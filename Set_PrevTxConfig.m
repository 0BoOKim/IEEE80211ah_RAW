function [Tab_PrevTxConfig] = Set_PrevTxConfig(Node_ID,Tab_PrevTxConfig, TxProb, TxWeight)

    Tab_PrevTxConfig(Node_ID, 1) = TxProb;
    Tab_PrevTxConfig(Node_ID, 2) = TxWeight;
    
end

