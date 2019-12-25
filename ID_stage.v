`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //from es
    input                          es_valid      ,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //from ms
    input                          ms_valid      ,
    input                          ms_load_op    ,
    input  [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input                          ws_valid      ,
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input                          ws_cancel
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire        ds_tlb_refill;
wire        fs_ex;
wire [ 4:0] fs_exccode;
wire        ds_bd;
wire [31:0] ds_badvaddr;
wire [31:0] ds_inst;
wire [31:0] ds_pc;
assign {ds_tlb_refill,  //103:103
        fs_ex        ,  //102:102
        fs_exccode   ,  //101:97
        ds_bd        ,  //96:96
        ds_badvaddr  ,  //95:64
        ds_inst      ,  //63:32
        ds_pc           //31:0      
       } = fs_to_ds_bus_r;

wire [ 3:0] rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //40:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_op;
wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

//ds_to_es_bus
wire        tlbp_op;
wire        tlbwi_op;
wire        tlbr_op;
wire        ds_ex;
wire [ 4:0] ds_exccode;
wire        ov_op;
wire        eret_op;
wire        mfc0_op;
wire        mtc0_op;
wire [ 7:0] cp0_addr;

wire [11:0] alu_op;
wire        lb_op;
wire        lbu_op;
wire        lh_op;
wire        lhu_op;
wire        lw_op;
wire        lwl_op;
wire        lwr_op;
wire        sb_op;
wire        sh_op;
wire        sw_op;
wire        swl_op;
wire        swr_op;
wire        mul_op;
wire        mulu_op;
wire        div_op;
wire        divu_op;

wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_signed_imm;
wire        src2_is_zero_imm;
wire        src2_is_8;
wire        res_from_mem;

wire        gr_we;
wire        mem_we;
wire        hi_re;
wire        lo_re;
wire        hi_we;
wire        lo_we;

wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [ 2:0] sel;

wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;
wire        inst_addu;
wire        inst_sub;
wire        inst_subu;
wire        inst_slt;
wire        inst_slti;
wire        inst_sltu;
wire        inst_sltiu;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_and;
wire        inst_andi;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_xori;
wire        inst_nor;
wire        inst_sll;
wire        inst_sllv;
wire        inst_srl;
wire        inst_srlv;
wire        inst_sra;
wire        inst_srav;
wire        inst_addi;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lw;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_sw;
wire        inst_swl;
wire        inst_swr;
wire        inst_beq;
wire        inst_bne;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_bgezal;
wire        inst_bltzal;
wire        inst_j;
wire        inst_jal;
wire        inst_jr;
wire        inst_jalr;
wire        inst_eret;
wire        inst_mfc0;
wire        inst_mtc0;
wire        inst_syscall;
wire        inst_break;
wire        inst_tlbp;
wire        inst_tlbwi;
wire        inst_tlbr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_eq_zero;
wire        rs_lt_zero;

assign br_bus       = {br_op, br_stall, br_taken, br_target};

assign ds_to_es_bus = {ds_tlb_refill,  //210:210
                       tlbp_op      ,  //209:209
                       tlbwi_op     ,  //208:208
                       tlbr_op      ,  //207:207
                       ds_ex        ,  //206:206
                       ds_exccode   ,  //205:201
                       ds_bd        ,  //200:200
                       ds_badvaddr  ,  //199:168
                       ov_op        ,  //167:167
                       eret_op      ,  //166:166
                       mfc0_op      ,  //165:165
                       mtc0_op      ,  //164:164
                       cp0_addr     ,  //163:156
                       alu_op       ,  //155:144
                       lb_op        ,  //143:143
                       lbu_op       ,  //142:142
                       lh_op        ,  //141:141
                       lhu_op       ,  //140:140
                       lw_op        ,  //139:139
                       lwl_op       ,  //138:138
                       lwr_op       ,  //137:137
                       sb_op        ,  //136:136
                       sh_op        ,  //135:135
                       sw_op        ,  //134:134
                       swl_op       ,  //133:133
                       swr_op       ,  //132:132
                       mul_op       ,  //131:131
                       mulu_op      ,  //130:130
                       div_op       ,  //129:129
                       divu_op      ,  //128:128
                       src1_is_sa   ,  //127:127
                       src1_is_pc   ,  //126:126
                       src2_is_signed_imm ,  //125:125
                       src2_is_zero_imm,  //124:124
                       src2_is_8    ,  //123:123
                       gr_we        ,  //122:122
                       mem_we       ,  //121:121
                       hi_re        ,  //120:120
                       lo_re        ,  //119:119
                       hi_we        ,  //118:118
                       lo_we        ,  //117:117
                       dest         ,  //116:112
                       imm          ,  //111:96
                       rs_value     ,  //95 :64
                       rt_value     ,  //63 :32
                       ds_pc           //31 :0
                      };

//exe_stage
wire        es_mtc0_op;
wire [ 7:0] es_cp0_addr;
wire        es_mfc0_op;
wire        es_load_op;
wire        es_gr_we;
wire [ 4:0] es_dest;
wire [31:0] es_alu_result;
assign es_mtc0_op    = es_to_ms_bus[120];
assign es_cp0_addr   = es_to_ms_bus[119:112];
assign es_mfc0_op    = es_to_ms_bus[79];
assign es_load_op    = es_to_ms_bus[78];
assign es_gr_we      = es_to_ms_bus[69];
assign es_dest       = es_to_ms_bus[68:64];
assign es_alu_result = es_to_ms_bus[63:32];

//mem_stage
wire        ms_mtc0_op;
wire [ 7:0] ms_cp0_addr;
wire        ms_mfc0_op;
wire [ 3:0] ms_rf_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_final_result;
assign ms_mtc0_op      = ms_to_ws_bus[114];
assign ms_cp0_addr     = ms_to_ws_bus[113:106];
assign ms_mfc0_op      = ms_to_ws_bus[73];
assign ms_rf_we        = ms_to_ws_bus[72:69];
assign ms_dest         = ms_to_ws_bus[68:64];
assign ms_final_result = ms_to_ws_bus[63:32];

wire load_block;
assign load_block = es_valid && es_load_op && es_dest != 5'b0 && (es_dest == rs || es_dest == rt)
                 || ms_valid && ms_load_op && ms_dest != 5'b0 && (ms_dest == rs || ms_dest == rt);
wire mfc0_block;
assign mfc0_block = es_valid && es_mfc0_op && es_dest != 5'b0 && (es_dest == rs || es_dest == rt)
                 || ms_valid && ms_mfc0_op && ms_dest != 5'b0 && (ms_dest == rs || ms_dest == rt);
wire tlb_block;
assign tlb_block = tlbp_op && (es_valid && es_mtc0_op && es_cp0_addr == `CR_ENTRYHI
                            || ms_valid && ms_mtc0_op && ms_cp0_addr == `CR_ENTRYHI);

assign ds_ready_go    = !load_block && !mfc0_block && !tlb_block;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    //bug 3
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ws_cancel)
        ds_valid <= 1'b0;
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];
assign sel  = ds_inst[ 2: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_addiu  = op_d[6'h09];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lb     = op_d[6'h20];
assign inst_lh     = op_d[6'h21];
assign inst_lwl    = op_d[6'h22];
assign inst_lw     = op_d[6'h23];
assign inst_lbu    = op_d[6'h24];
assign inst_lhu    = op_d[6'h25];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_sw     = op_d[6'h2b];
assign inst_swr    = op_d[6'h2e];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_j      = op_d[6'h02];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_eret   = ds_inst == 32'b010000_1_000_0000_0000_0000_0000_011000;
assign inst_tlbp   = ds_inst == 32'b010000_1_000_0000_0000_0000_0000_001000;
assign inst_tlbwi  = ds_inst == 32'b010000_1_000_0000_0000_0000_0000_000010;
assign inst_tlbr   = ds_inst == 32'b010000_1_000_0000_0000_0000_0000_000001;
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & ds_inst[10:3] == 8'h00;
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & ds_inst[10:3] == 8'h00;

assign inst_syscall = op_d[6'h00] & func_d[6'h0c];
assign inst_break   = op_d[6'h00] & func_d[6'h0d];

assign alu_op[ 0] = inst_add | inst_addu | inst_addi | inst_addiu | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_sw | inst_swl | inst_swr | inst_bgezal | inst_bltzal | inst_jal | inst_jalr;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;

assign lb_op   = inst_lb;
assign lbu_op  = inst_lbu;
assign lh_op   = inst_lh;
assign lhu_op  = inst_lhu;
assign lw_op   = inst_lw;
assign lwl_op  = inst_lwl;
assign lwr_op  = inst_lwr;
assign sb_op   = inst_sb;
assign sh_op   = inst_sh;
assign sw_op   = inst_sw;
assign swl_op  = inst_swl;
assign swr_op  = inst_swr;
assign mul_op  = inst_mult;
assign mulu_op = inst_multu;
assign div_op  = inst_div;
assign divu_op = inst_divu;

assign src1_is_sa   = inst_sll | inst_srl | inst_sra;
assign src1_is_pc   = inst_bgezal | inst_bltzal | inst_jal | inst_jalr;
assign src2_is_signed_imm  = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_lui | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_sw | inst_swl | inst_swr;
assign src2_is_zero_imm = inst_andi | inst_ori | inst_xori;
assign src2_is_8    = inst_bgezal | inst_bltzal | inst_jal | inst_jalr;
assign res_from_mem = inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw | inst_lwl | inst_lwr;
assign dst_is_r31   = inst_bgezal | inst_bltzal | inst_jal;
assign dst_is_rt    = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_lui | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw | inst_lwl | inst_lwr | inst_mfc0;

assign gr_we        = ~inst_sb & ~inst_sh & ~inst_sw & ~inst_swl & ~inst_swr & ~inst_beq & ~inst_bne & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_j & ~inst_jr & ~inst_mult & ~inst_multu & ~inst_div & ~inst_divu & ~inst_mthi & ~inst_mtlo & ~inst_eret & ~inst_tlbp & ~inst_tlbwi & ~inst_tlbr & ~inst_mtc0 & ~inst_syscall & ~inst_break;
assign mem_we       = inst_sb | inst_sh | inst_sw | inst_swl | inst_swr;
assign hi_re        = inst_mfhi;
assign lo_re        = inst_mflo;
assign hi_we        = inst_mthi;
assign lo_we        = inst_mtlo;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value[ 7: 0] = (es_valid && es_gr_we    && es_dest == rs) ? es_alu_result[7:0] : 
                         (ms_valid && ms_rf_we[0] && ms_dest == rs) ? ms_final_result[7:0] : 
                         (ws_valid && rf_we[0]    && rf_waddr == rs) ? rf_wdata[7:0] : 
                         rf_rdata1[7:0];
assign rs_value[15: 8] = (es_valid && es_gr_we    && es_dest == rs) ? es_alu_result[15:8] : 
                         (ms_valid && ms_rf_we[1] && ms_dest == rs) ? ms_final_result[15:8] : 
                         (ws_valid && rf_we[1]    && rf_waddr == rs) ? rf_wdata[15:8] : 
                         rf_rdata1[15:8];
assign rs_value[23:16] = (es_valid && es_gr_we    && es_dest == rs) ? es_alu_result[23:16] : 
                         (ms_valid && ms_rf_we[2] && ms_dest == rs) ? ms_final_result[23:16] : 
                         (ws_valid && rf_we[2]    && rf_waddr == rs) ? rf_wdata[23:16] : 
                         rf_rdata1[23:16];
assign rs_value[31:24] = (es_valid && es_gr_we    && es_dest == rs) ? es_alu_result[31:24] : 
                         (ms_valid && ms_rf_we[3] && ms_dest == rs) ? ms_final_result[31:24] : 
                         (ws_valid && rf_we[3]    && rf_waddr == rs) ? rf_wdata[31:24] : 
                         rf_rdata1[31:24];

assign rt_value[ 7: 0] = (es_valid && es_gr_we    && es_dest == rt)  ? es_alu_result[7:0] : 
                         (ms_valid && ms_rf_we[0] && ms_dest == rt)  ? ms_final_result[7:0] : 
                         (ws_valid && rf_we[0]    && rf_waddr == rt) ? rf_wdata[7:0] : 
                         rf_rdata2[7:0];
assign rt_value[15: 8] = (es_valid && es_gr_we    && es_dest == rt)  ? es_alu_result[15:8] : 
                         (ms_valid && ms_rf_we[1] && ms_dest == rt)  ? ms_final_result[15:8] : 
                         (ws_valid && rf_we[1]    && rf_waddr == rt) ? rf_wdata[15:8] : 
                         rf_rdata2[15:8];
assign rt_value[23:16] = (es_valid && es_gr_we    && es_dest == rt)  ? es_alu_result[23:16] : 
                         (ms_valid && ms_rf_we[2] && ms_dest == rt)  ? ms_final_result[23:16] : 
                         (ws_valid && rf_we[2]    && rf_waddr == rt) ? rf_wdata[23:16] : 
                         rf_rdata2[23:16];
assign rt_value[31:24] = (es_valid && es_gr_we    && es_dest == rt)  ? es_alu_result[31:24] : 
                         (ms_valid && ms_rf_we[3] && ms_dest == rt)  ? ms_final_result[31:24] : 
                         (ws_valid && rf_we[3]    && rf_waddr == rt) ? rf_wdata[31:24] : 
                         rf_rdata2[31:24];

assign rs_eq_rt = (rs_value == rt_value);
assign rs_eq_zero = (rs_value == 32'b0);
assign rs_lt_zero = (rs_value[31] == 1'b1);

assign br_op = (inst_beq    | inst_bne | 
                inst_bgez   | inst_bgtz   | inst_blez | inst_bltz | 
                inst_bgezal | inst_bltzal | 
                inst_j      | inst_jal    | inst_jr   | inst_jalr
               ) && (ds_valid || br_stall); //ds_pcÊÇ×ªÒÆÖ¸Áî
assign br_stall = load_block || mfc0_block;
assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgez   && !rs_lt_zero
                   || inst_bgtz   && !rs_lt_zero && !rs_eq_zero
                   || inst_blez   && (rs_lt_zero ||  rs_eq_zero)
                   || inst_bltz   &&  rs_lt_zero
                   || inst_bgezal && !rs_lt_zero
                   || inst_bltzal &&  rs_lt_zero
                   || inst_j
                   || inst_jal 
                   || inst_jr
                   || inst_jalr
                  ) && ds_valid && !br_stall;
wire [31:0] slot_pc;
assign slot_pc = ds_pc + 3'h4;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bgezal || inst_bltzal) ? (slot_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr) ?  rs_value :
                   /*(inst_jal || inst_j)*/  {slot_pc[31:28], jidx[25:0], 2'b0};

//exception
wire ex_sys;
wire ex_bp;
wire ex_ri;
assign ex_sys = inst_syscall;
assign ex_bp = inst_break;
assign ex_ri = ~inst_add   & ~inst_addi & ~inst_addu  & ~inst_addiu & ~inst_sub  & ~inst_subu & 
               ~inst_slt   & ~inst_slti & ~inst_sltu  & ~inst_sltiu & 
               ~inst_div   & ~inst_divu & ~inst_mult  & ~inst_multu & 
               ~inst_and   & ~inst_andi & ~inst_lui   & ~inst_nor   & ~inst_or   & ~inst_ori  & ~inst_xor    & ~inst_xori & 
               ~inst_sllv  & ~inst_sll  & ~inst_srav  & ~inst_sra   & ~inst_srlv & ~inst_srl  & 
               ~inst_beq   & ~inst_bne  & ~inst_bgez  & ~inst_bgtz  & ~inst_blez & ~inst_bltz & ~inst_bgezal & ~inst_bltzal & 
               ~inst_j     & ~inst_jal  & ~inst_jr    & ~inst_jalr  & 
               ~inst_mfhi  & ~inst_mflo & ~inst_mthi  & ~inst_mtlo  & 
               ~inst_break & ~inst_syscall & 
               ~inst_lb    & ~inst_lbu  & ~inst_lh    & ~inst_lhu   & ~inst_lw   & ~inst_lwl  & ~inst_lwr & 
               ~inst_sb    & ~inst_sh   & ~inst_sw    & ~inst_swl   & ~inst_swr  & 
               ~inst_eret  & ~inst_tlbp & ~inst_tlbwi & ~inst_tlbr  & ~inst_mfc0 & ~inst_mtc0;
               
assign ds_ex = ds_valid && (fs_ex | ex_ri | ex_bp | ex_sys);
assign ds_exccode = fs_ex      ? fs_exccode :
                    ex_ri      ? `EX_RI     :
                    ex_bp      ? `EX_BP     :
                    ex_sys     ? `EX_SYS    :
                                 5'h00      ;

assign ov_op    = inst_add | inst_addi | inst_sub;
assign eret_op  = inst_eret;
assign mfc0_op  = inst_mfc0;
assign mtc0_op  = inst_mtc0;
assign cp0_addr = {rd, sel};

assign tlbp_op  = inst_tlbp;
assign tlbwi_op = inst_tlbwi;
assign tlbr_op  = inst_tlbr;

endmodule
