module mycpu_core(
    input         clk,
    input         resetn,
    
    // external interrupt
    input  [ 5:0] ext_int_in,
    
    // inst sram interface
    output        inst_sram_req,
    output [ 2:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    input         inst_sram_rdy,
    input         inst_sram_valid,
    input         inst_sram_last,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 2:0] data_sram_size,
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

wire        icache_valid;
wire        icache_op;
wire [ 7:0] icache_index;
wire [19:0] icache_tlb_tag;
wire [ 3:0] icache_offset;
wire [ 3:0] icache_wstrb;
wire [31:0] icache_wdata;
wire        icache_addrok;
wire        icache_dataok;
wire [31:0] icache_rdata;

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

wire [18:0] entryhi_vpn2;
wire [ 7:0] entryhi_asid;
wire [ 5:0] tlbp_bus;

//TLB
wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire [ 7:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_d;
wire        s0_v;

wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire [ 7:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v;

wire        we;
wire [ 3:0] w_index;
wire [18:0] w_vpn2;
wire [ 7:0] w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [ 2:0] w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [ 2:0] w_c1;
wire        w_d1;
wire        w_v1;

wire [ 3:0] r_index;
wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire        r_d1;
wire        r_v1;

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
    .icache_valid    (icache_valid    ),
    .icache_op       (icache_op       ),
    .icache_index    (icache_index    ),
    .icache_tlb_tag  (icache_tlb_tag  ),
    .icache_offset   (icache_offset   ),
    .icache_wstrb    (icache_wstrb    ),
    .icache_wdata    (icache_wdata    ),
    .icache_addrok   (icache_addrok   ),
    .icache_dataok   (icache_dataok   ),
    .icache_rdata    (icache_rdata    ),
    //exception
    .ws_cancel       (ws_cancel       ),
    .new_pc          (new_pc          ),
    //TLB
    .s0_vpn2         (s0_vpn2         ),
    .s0_odd_page     (s0_odd_page     ),
    .s0_asid         (s0_asid         ),
    .s0_found        (s0_found        ),
    .s0_index        (s0_index        ),
    .s0_pfn          (s0_pfn          ),
    .s0_c            (s0_c            ),
    .s0_d            (s0_d            ),
    .s0_v            (s0_v            ),
    .entryhi_asid    (entryhi_asid    )
);
//icache
cache icache(
    .clk      (clk),
    .resetn   (resetn),
    
    .valid    (icache_valid),
    .op       (icache_op),
    .index    (icache_index),
    .tlb_tag  (icache_tlb_tag),
    .offset   (icache_offset),
    .wstrb    (icache_wstrb),
    .wdata    (icache_wdata),
    .addr_ok  (icache_addrok),
    .data_ok  (icache_dataok),
    .rdata    (icache_rdata),

    .rd_req   (inst_sram_req),
    .rd_type  (inst_sram_size),
    .rd_addr  (inst_sram_addr),
    .rd_rdy   (inst_sram_rdy),
    .ret_valid(inst_sram_valid),
    .ret_last (inst_sram_last),
    .ret_data (inst_sram_rdata)
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
    .ws_cancel       (ws_cancel       ),
    //TLB
    .s1_vpn2         (s1_vpn2         ),
    .s1_odd_page     (s1_odd_page     ),
    .s1_asid         (s1_asid         ),
    .s1_found        (s1_found        ),
    .s1_index        (s1_index        ),
    .s1_pfn          (s1_pfn          ),
    .s1_c            (s1_c            ),
    .s1_d            (s1_d            ),
    .s1_v            (s1_v            ),
    .entryhi_vpn2    (entryhi_vpn2    ),
    .entryhi_asid    (entryhi_asid    ),
    .tlbp_bus        (tlbp_bus        )
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
    //exception
    .ms_cancel       (ms_cancel       ),
    .ws_cancel       (ws_cancel       )
);
// WB stage
wb_stage wb_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    .ext_int_in       (ext_int_in       ),
    //allowin
    .ws_allowin       (ws_allowin       ),
    //from ms
    .ms_to_ws_valid   (ms_to_ws_valid   ),
    .ms_to_ws_bus     (ms_to_ws_bus     ),
    //to rf: for write back
    .ws_to_rf_bus     (ws_to_rf_bus     ),
    //to ds
    .ws_valid         (ws_valid         ),
    //to es
    .has_int          (has_int          ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //exception
    .ws_cancel        (ws_cancel        ),
    .new_pc           (new_pc           ),
    //TLB
    .entryhi_vpn2     (entryhi_vpn2     ),
    .entryhi_asid     (entryhi_asid     ),
    .tlbp_bus         (tlbp_bus         ),
    
    .we          (we     ),
    .w_index     (w_index),
    .w_vpn2      (w_vpn2 ),
    .w_asid      (w_asid ),
    .w_g         (w_g    ),
    .w_pfn0      (w_pfn0 ),
    .w_c0        (w_c0   ),
    .w_d0        (w_d0   ),
    .w_v0        (w_v0   ),
    .w_pfn1      (w_pfn1 ),
    .w_c1        (w_c1   ),
    .w_d1        (w_d1   ),
    .w_v1        (w_v1   ),
    
    .r_index     (r_index),
    .r_vpn2      (r_vpn2),
    .r_asid      (r_asid),
    .r_g         (r_g),
    .r_pfn0      (r_pfn0),
    .r_c0        (r_c0),
    .r_d0        (r_d0),
    .r_v0        (r_v0),
    .r_pfn1      (r_pfn1),
    .r_c1        (r_c1),
    .r_d1        (r_d1),
    .r_v1        (r_v1)
);

//TLB
tlb u_tlb(
    .clk         (clk),
    //search port 0
    .s0_vpn2     (s0_vpn2),
    .s0_odd_page (s0_odd_page),
    .s0_asid     (s0_asid),
    .s0_found    (s0_found),
    .s0_index    (s0_index),
    .s0_pfn      (s0_pfn),
    .s0_c        (s0_c),
    .s0_d        (s0_d),
    .s0_v        (s0_v),
    //search prot 1
    .s1_vpn2     (s1_vpn2),
    .s1_odd_page (s1_odd_page),
    .s1_asid     (s1_asid),
    .s1_found    (s1_found),
    .s1_index    (s1_index),
    .s1_pfn      (s1_pfn),
    .s1_c        (s1_c),
    .s1_d        (s1_d),
    .s1_v        (s1_v),
    //write
    .we          (we),
    .w_index     (w_index),
    .w_vpn2      (w_vpn2),
    .w_asid      (w_asid),
    .w_g         (w_g),
    .w_pfn0      (w_pfn0),
    .w_c0        (w_c0),
    .w_d0        (w_d0),
    .w_v0        (w_v0),
    .w_pfn1      (w_pfn1),
    .w_c1        (w_c1),
    .w_d1        (w_d1),
    .w_v1        (w_v1),
    //read
    .r_index     (r_index),
    .r_vpn2      (r_vpn2),
    .r_asid      (r_asid),
    .r_g         (r_g),
    .r_pfn0      (r_pfn0),
    .r_c0        (r_c0),
    .r_d0        (r_d0),
    .r_v0        (r_v0),
    .r_pfn1      (r_pfn1),
    .r_c1        (r_c1),
    .r_d1        (r_d1),
    .r_v1        (r_v1)
);

endmodule
