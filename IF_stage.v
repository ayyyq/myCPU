`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram-like interface
    output        icache_valid  ,
    output        icache_op     ,
    output [ 7:0] icache_index  ,
    output [19:0] icache_tlb_tag,
    output [ 3:0] icache_offset ,
    output [ 3:0] icache_wstrb  ,
    output [31:0] icache_wdata  ,
    input         icache_addrok ,
    input         icache_dataok ,
    input  [31:0] icache_rdata  ,                       
    //exception
    input         ws_cancel     ,
    input  [31:0] new_pc        ,
    //TLB
    output [18:0] s0_vpn2       ,
    output        s0_odd_page   ,
    output [ 7:0] s0_asid       ,
    input         s0_found      ,
    input  [ 3:0] s0_index      ,
    input  [19:0] s0_pfn        ,
    input  [ 2:0] s0_c          ,
    input         s0_d          ,
    input         s0_v          ,
    
    input  [ 7:0] entryhi_asid
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;
reg         buf_npc_valid;
reg  [31:0] buf_npc;
wire [31:0] true_npc;

wire        br_op;
wire        br_stall;
wire        br_taken;
wire [31:0] br_target;
reg         br_bus_valid;
reg  [34:0] br_bus_r;
wire [34:0] true_br_bus;
assign {br_op    ,
        br_stall ,
        br_taken ,
        br_target} = true_br_bus;

//buffer
assign true_br_bus = br_bus_valid ? br_bus_r : br_bus;
always @(posedge clk) begin
    if (reset)
        br_bus_valid <= 1'b0;
    else if (ws_cancel)
        br_bus_valid <= 1'b0;
    else if (br_op && !br_stall && !(fs_valid && fs_allowin))
        br_bus_valid <= 1'b1; //只记录有效的br_bus
    else if (fs_allowin)
        br_bus_valid <= 1'b0;
    
    if (!br_bus_valid)
        br_bus_r <= br_bus;
end

wire        fs_tlb_refill;
wire        fs_ex;
wire [ 4:0] fs_exccode;
wire        fs_bd;
wire [31:0] fs_badvaddr;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_tlb_refill,  //103:103
                       fs_ex        ,  //102:102
                       fs_exccode   ,  //101:97
                       fs_bd        ,  //96:96
                       fs_badvaddr  ,  //95:64
                       fs_inst      ,  //63:32
                       fs_pc           //31:0
                      };

wire unmapped;

// pre-IF stage
assign to_fs_valid  = ~reset && icache_addrok; //表示有数据需要在下一拍传给IF级
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

//buffer
assign true_npc = buf_npc_valid ? buf_npc : nextpc;
always @(posedge clk)begin
    if (reset)
        buf_npc_valid <= 1'b0;
    else if (ws_cancel)
        buf_npc_valid <= 1'b0;
    else if (to_fs_valid && fs_allowin)
        buf_npc_valid <= 1'b0;
    else if (!buf_npc_valid && !br_stall)
        buf_npc_valid <= 1'b1;
     
    if (!buf_npc_valid)
        buf_npc <=  nextpc;
end

//TLB
assign unmapped = true_npc[31] && !true_npc[30];

assign s0_vpn2 = true_npc[31:13];
assign s0_odd_page = true_npc[12];
assign s0_asid = entryhi_asid;

// IF stage
wire ex_adel;
reg  ex_tlb_refill;
reg  ex_tlb_invalid;

reg fs_ready_go_r;
always @(posedge clk) begin
    if (reset)
        fs_ready_go_r <= 1'b0;
    else if (fs_ready_go && !ds_allowin)
        fs_ready_go_r <= 1'b1;
    else if (ds_allowin)
        fs_ready_go_r <= 1'b0;
end
assign fs_ready_go    = icache_dataok || fs_ready_go_r || fs_exccode == `EX_TLBL; //表示IF级拿到指令可以传递到ID级了
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (ws_cancel)
        fs_valid <= 1'b0;
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (ws_cancel)
        fs_pc <= new_pc - 3'h4;
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= true_npc;
    end
end

//buffer
reg buf_rdata_valid;
reg [31:0] buf_rdata;
always @(posedge clk) begin
    if (reset)
        buf_rdata_valid <= 1'b0;
    else if (ds_allowin)
        buf_rdata_valid <= 1'b0;
    else if (!buf_rdata_valid)
        buf_rdata_valid <= icache_dataok;
    
    if (!buf_rdata_valid && icache_dataok)
        buf_rdata <= icache_rdata;
end

//exception
assign ex_adel = fs_pc[1:0] != 2'b00;
always @(posedge clk) begin
    if (reset)
        ex_tlb_refill <= 1'b0;
    else if (to_fs_valid && fs_allowin)
        ex_tlb_refill <= !unmapped && !s0_found;
end
always @(posedge clk) begin
    if (reset)
        ex_tlb_invalid <= 1'b0;
    else if (to_fs_valid && fs_allowin)
        ex_tlb_invalid <= !unmapped && s0_found && !s0_v;
end

assign fs_tlb_refill = fs_exccode == `EX_TLBL && ex_tlb_refill;
assign fs_ex = fs_valid && (ex_adel | ex_tlb_refill | ex_tlb_invalid);
assign fs_exccode = ex_adel ?        `EX_ADEL : 
                    ex_tlb_refill  ? `EX_TLBL : 
                    ex_tlb_invalid ? `EX_TLBL : 
                                     5'h00;
assign fs_bd = br_op;
assign fs_badvaddr = fs_pc;

//当IF级allowin时，preIF级才发req
assign icache_valid = to_fs_valid && fs_allowin && (unmapped || s0_found && s0_v); //en
assign icache_op = 1'h0; //wen
assign icache_index = true_npc[11:4];
assign icache_tlb_tag = unmapped ? true_npc[31:12] : s0_pfn;
assign icache_offset = true_npc[3:0];
assign icache_wstrb = 4'h0; //wen
assign icache_wdata = 32'd0;

assign fs_inst         = buf_rdata_valid ? buf_rdata : icache_rdata;

endmodule
