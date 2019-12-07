module mycpu_core(
    input         clk,
    input         resetn,
    
    // external interrupt
    input  [ 5:0] ext_int_in,
    
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    input         inst_sram_addrok,
    input         inst_sram_dataok,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [31:0] data_sram_addr,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    input         data_sram_addrok,
    input         data_sram_dataok,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire es_valid;
wire ms_valid;
wire ws_valid;
wire has_int;
wire ms_load_op;
wire ms_cancel;
wire ws_cancel;
wire [31:0] new_pc;

// IF stage
if_stage if_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    //allowin
    .ds_allowin      (ds_allowin      ),
    //brbus
    .br_bus          (br_bus          ),
    //outputs
    .fs_to_ds_valid  (fs_to_ds_valid  ),
    .fs_to_ds_bus    (fs_to_ds_bus    ),
    // inst sram interface
    .inst_sram_req   (inst_sram_req   ),
    .inst_sram_wr    (inst_sram_wr    ),
    .inst_sram_size  (inst_sram_size  ),
    .inst_sram_addr  (inst_sram_addr  ),
    .inst_sram_wstrb (inst_sram_wstrb ),
    .inst_sram_wdata (inst_sram_wdata ),
    .inst_sram_rdata (inst_sram_rdata ),
    .inst_sram_addrok(inst_sram_addrok),
    .inst_sram_dataok(inst_sram_dataok),
    //exception
    .ws_cancel       (ws_cancel       ),
    .new_pc          (new_pc          )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //from es
    .es_valid       (es_valid       ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //from ms
    .ms_valid       (ms_valid       ),
    .ms_load_op     (ms_load_op     ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_valid       (ws_valid       ),
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ws_cancel      (ws_cancel      )
);
// EXE stage
exe_stage exe_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    //allowin
    .ms_allowin      (ms_allowin      ),
    .es_allowin      (es_allowin      ),
    //from ds
    .ds_to_es_valid  (ds_to_es_valid  ),
    .ds_to_es_bus    (ds_to_es_bus    ),
    //from ws
    .has_int         (has_int         ),
    //to ds
    .es_valid        (es_valid        ),
    //to ms
    .es_to_ms_valid  (es_to_ms_valid  ),
    .es_to_ms_bus    (es_to_ms_bus    ),
    // data sram interface
    .data_sram_req   (data_sram_req   ),
    .data_sram_wr    (data_sram_wr    ),
    .data_sram_size  (data_sram_size  ),
    .data_sram_addr  (data_sram_addr  ),
    .data_sram_wstrb (data_sram_wstrb ),
    .data_sram_wdata (data_sram_wdata ),
    .data_sram_addrok(data_sram_addrok),
    //exception
    .ms_cancel       (ms_cancel       ),
    .ws_cancel       (ws_cancel       )
);
// MEM stage
mem_stage mem_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    //allowin
    .ws_allowin      (ws_allowin      ),
    .ms_allowin      (ms_allowin      ),
    //from es
    .es_to_ms_valid  (es_to_ms_valid  ),
    .es_to_ms_bus    (es_to_ms_bus    ),
    //to ws
    .ms_to_ws_valid  (ms_to_ws_valid  ),
    .ms_to_ws_bus    (ms_to_ws_bus    ),
    //to ds
    .ms_valid        (ms_valid        ),
    .ms_load_op      (ms_load_op      ),
    //from data-sram
    .data_sram_rdata (data_sram_rdata ),
    .data_sram_dataok(data_sram_dataok),
    //excepiton
    .ms_cancel       (ms_cancel       ),
    .ws_cancel       (ws_cancel       )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .ext_int_in     (ext_int_in     ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to ds
    .ws_valid       (ws_valid       ),
    // to es
    .has_int        (has_int        ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //exception
    .ws_cancel        (ws_cancel        ),
    .new_pc           (new_pc           )
);

endmodule
