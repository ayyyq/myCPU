`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       34 //bus 5
    `define FS_TO_DS_BUS_WD 103
    `define DS_TO_ES_BUS_WD 207
    `define ES_TO_MS_BUS_WD 161
    `define MS_TO_WS_BUS_WD 155
    `define WS_TO_RF_BUS_WD 41
    
    `define CR_BADVADDR {5'd8, 3'd0}
    `define CR_COUNT    {5'd9, 3'd0}
    `define CR_COMPARE  {5'd11, 3'd0}
    `define CR_STATUS   {5'd12, 3'd0}
    `define CR_CAUSE    {5'd13, 3'd0}
    `define CR_EPC      {5'd14, 3'd0}

    `define EX_INT 5'h00
    `define EX_ADEL 5'h04
    `define EX_ADES 5'h05
    `define EX_OV 5'h0c
    `define EX_SYS 5'h08
    `define EX_BP 5'h09
    `define EX_RI 5'h0a
`endif
