`define IDLE 3'd0
`define LOOKUP 3'd1
`define MISS 3'd2
`define REPLACE 3'd3
`define REFILL 3'd4

module cache
(
	input clk,
	input resetn,
	
    //cache and cpu_core
	input         valid,
	input         op,
	input  [ 7:0] index,
	input  [19:0] tlb_tag,
	input  [ 3:0] offset,
	input  [ 3:0] wstrb,
	input  [31:0] wdata,
	output        addr_ok,
	output        data_ok,
	output [31:0] rdata,
	
    //cache and interface
	output        rd_req,
	output [ 2:0] rd_type,
	output [31:0] rd_addr,
	input         rd_rdy,
	input         ret_valid,
	input         ret_last,
	input  [31:0] ret_data,

	output         wr_req,
	output [  2:0] wr_type,
	output [ 31:0] wr_addr,
	output [  3:0] wr_wstrb,
	output [127:0] wr_data,
	input          wr_rdy
);

reg        op_r;
reg [ 7:0] index_r;
reg [19:0] tlb_tag_r;
reg [ 3:0] offset_r;
reg [ 3:0] wstrb_r;
reg [31:0] wdata_r;

wire rw_conflict;

wire [19:0]  way0_tag;
wire         way0_v;
wire [127:0] way0_data;
wire [19:0]  way1_tag;
wire         way1_v;
wire [127:0] way1_data;

wire way0_hit;
wire way1_hit;
wire cache_hit;

wire [31:0] way0_load_word;
wire [31:0] way1_load_word;
wire [31:0] load_res;
wire [31:0] refill_data;

wire replace_way;
reg  replace_way_r;
reg  [127:0] replace_data;
reg  [19:0] cache_tag;
reg  cache_v;
wire cache_d;

reg [2:0] count;

wire [ 7:0] addr_tv0;
wire [31:0] rdata_tv0;
wire        en_tv0;
wire [ 3:0] we_tv0;
wire [ 7:0] addr_tv1;
wire [31:0] rdata_tv1;
wire        en_tv1;
wire [ 3:0] we_tv1;

reg [255:0] way0_d_rf;
reg [255:0] way1_d_rf;

wire [ 7:0] addr_bank0_0;
wire [ 7:0] addr_bank0_1;
wire [ 7:0] addr_bank0_2;
wire [ 7:0] addr_bank0_3;
wire [31:0] wdata_bank0_0;
wire [31:0] wdata_bank0_1;
wire [31:0] wdata_bank0_2;
wire [31:0] wdata_bank0_3;
wire        en_bank0_0;
wire        en_bank0_1;
wire        en_bank0_2;
wire        en_bank0_3;
wire [ 3:0] we_bank0_0;
wire [ 3:0] we_bank0_1;
wire [ 3:0] we_bank0_2;
wire [ 3:0] we_bank0_3;

wire [ 7:0] addr_bank1_0;
wire [ 7:0] addr_bank1_1;
wire [ 7:0] addr_bank1_2;
wire [ 7:0] addr_bank1_3;
wire [31:0] wdata_bank1_0;
wire [31:0] wdata_bank1_1;
wire [31:0] wdata_bank1_2;
wire [31:0] wdata_bank1_3;
wire        en_bank1_0;
wire        en_bank1_1;
wire        en_bank1_2;
wire        en_bank1_3;
wire [ 3:0] we_bank1_0;
wire [ 3:0] we_bank1_1;
wire [ 3:0] we_bank1_2;
wire [ 3:0] we_bank1_3;

reg [2:0] state;
reg [2:0] next_state;

//Cache模块状态转换机
always @(*) begin
    case (state)
        `IDLE: next_state = valid ? `LOOKUP : `IDLE; //接收新请求时（LOOKUP且cache_hit时也可能接收新请求）锁存请求信息，读所有路的Tag、V和Data的局部（只保证局部读出来的数据正确即可），在下一拍的LOOKUP得到读出结果
        `LOOKUP: next_state = !cache_hit ? `MISS : 
                              (valid && addr_ok) ? `LOOKUP : 
                              `IDLE; //判断Cache是否命中，如果store命中则同时将数据写入到命中Cache行的对应位置并将D置为1，一拍有效
        `MISS: next_state = (!(cache_v && cache_d) || wr_rdy) ? `REPLACE : `MISS; //记录Cache缺失时的信息，读待替换路的D，如果V=1且D=1，则向AXI总线发起写请求，将待替换的Cache行写回内存
        `REPLACE: next_state = rd_rdy ? `REFILL : `REPLACE; //向总线发起读请求
        `REFILL: next_state = ret_last ? `IDLE : `REFILL; //将内存返回的数据（以及store miss待写入的数据）填入到Cache中
        default: next_state = `IDLE;
    endcase
end
always @(posedge clk) begin
    if (!resetn)
        state <= `IDLE;
    else
        state <= next_state;
end

//Output
assign rw_conflict = op_r && 
                     valid && !op && 
                     offset_r[3:2] == offset[3:2]; //LOOKUP所处理操作是写操作，新请求是读请求，且请求地址的offset[3:2]相等，则读写冲突
assign addr_ok = state == `IDLE || state == `LOOKUP && cache_hit && !rw_conflict; //如果读写冲突，store在LOOKUP命中并发起Cache写请求当拍不会接收读请求，而是下一拍返回IDLE后接收，此时Cache更新完成（一个字）
assign data_ok = state == `LOOKUP && cache_hit || state == `REFILL && ret_valid && count == offset_r[3:2];
assign rdata = state == `REFILL ? ret_data : load_res;

//Request Buffer
always @(posedge clk) begin
    if (!resetn)
        replace_way_r <= 1'b0;
    //如果接收了请求，则记录来自流水线方向的请求信息，直到接收下一个请求
    if (valid && addr_ok) begin
        op_r <= op;
        index_r <= index;
        tlb_tag_r <= tlb_tag;
        offset_r <= offset;
        wstrb_r <= wstrb;
        wdata_r <= wdata;
    end
    //记录缺失Cache行准备要替换的路信息，直到接受下一个Cache缺失
    if (state == `LOOKUP && !cache_hit) begin
        replace_way_r <= replace_way;
        replace_data <= replace_way ? way1_data : way0_data;
        cache_tag <= replace_way ? way1_tag : way0_tag;
        cache_v <= replace_way ? way1_v : way0_v;
        //{tlb_tag_r, index_r, offset_r}同时是Cache缺失的地址
    end
    //记录已经从总线返回了几个数据的写使能
    if (state == `REPLACE && rd_rdy)
        count <= 3'd0;
    else if (state == `REFILL && ret_valid)
        count <= count + 3'd1; //3'd4
end

//Tag Compare
//LOOKUP
assign way0_hit = way0_v && (way0_tag == tlb_tag_r);
assign way1_hit = way1_v && (way1_tag == tlb_tag_r);
assign cache_hit = way0_hit || way1_hit;

//Data Select
//LOOKUP
assign way0_load_word = way0_data[offset_r[3:2]*32 +: 32];
assign way1_load_word = way1_data[offset_r[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word
                | {32{way1_hit}} & way1_load_word;
//REPLACE
assign refill_data[ 7: 0] = wstrb_r[0] ? wdata_r[ 7: 0] : ret_data[ 7: 0];
assign refill_data[15: 8] = wstrb_r[1] ? wdata_r[15: 8] : ret_data[15: 8];
assign refill_data[23:16] = wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16];
assign refill_data[31:24] = wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24];

//MISS
assign wr_req = state == `MISS && cache_v && cache_d;
assign wr_type = 3'b100;
assign wr_addr = {cache_tag, index_r, 4'd0};
assign wr_wstrb = 4'b1111;
assign wr_data = replace_data;

//REPLACE
assign rd_req = state == `REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {tlb_tag_r, index_r, 4'd0};

//LSFR
reg [4:0] pseudo_random;
always @(posedge clk)
begin
    if (!resetn)
        pseudo_random <= 5'h1;
    else
        pseudo_random <= {pseudo_random[0], pseudo_random[4], pseudo_random[3] ^ pseudo_random[0], pseudo_random[2], pseudo_random[1]};
end
assign replace_way = pseudo_random[0];

//{Tag, V}
assign en_tv0 = 1'b1;
assign we_tv0 = (state == `REFILL && !replace_way_r) ? 4'b1111 : 4'b0000;
assign addr_tv0 = we_tv0 ? index_r : index;

assign en_tv1 = 1'b1;
assign we_tv1 = (state == `REFILL && replace_way_r) ? 4'b1111 : 4'b0000;
assign addr_tv1 = we_tv1 ? index_r : index;

assign {way0_tag, way0_v} = rdata_tv0[20:0];
assign {way1_tag, way1_v} = rdata_tv1[20:0];

tag_v_ram way0_tv_ram(
    .addra (addr_tv0),
    .clka  (clk),
    .dina  ({11'd0, tlb_tag_r, 1'b1}),
    .douta (rdata_tv0), //只在LOOKUP当拍有效
    .ena   (en_tv0),
    .wea   (we_tv0)
);
tag_v_ram way1_tv_ram(
    .addra (addr_tv1),
    .clka  (clk),
    .dina  ({11'd0, tlb_tag_r, 1'b1}),
    .douta (rdata_tv1),
    .ena   (en_tv1),
    .wea   (we_tv1)
);

//D
always @(posedge clk) begin
    if (!resetn)
        way0_d_rf <= 256'd0;
    else if (state == `LOOKUP && way0_hit && op_r)
        way0_d_rf[index_r] <= 1'b1;
    else if (state == `REFILL && !replace_way_r)
        way0_d_rf[index_r] <= op_r;
end
always @(posedge clk) begin
    if (!resetn)
        way1_d_rf <= 256'd0;
    else if (state == `LOOKUP && way1_hit && op_r)
        way1_d_rf[index_r] <= 1'b1;
    else if (state == `REFILL && replace_way_r)
        way1_d_rf[index_r] <= op_r;
end
assign cache_d = replace_way_r ? way1_d_rf[index_r] : way0_d_rf[index_r]; //MISS

//Data
assign en_bank0_0 = 1'b1;
assign en_bank0_1 = 1'b1;
assign en_bank0_2 = 1'b1;
assign en_bank0_3 = 1'b1;
assign we_bank0_0 = (state == `LOOKUP && way0_hit && op_r && offset_r[3:2] == 2'd0) ? wstrb_r : 
                    (state == `REFILL && !replace_way_r && ret_valid && count == 3'd0) ? 4'b1111 : 
                    4'b0000;
assign we_bank0_1 = (state == `LOOKUP && way0_hit && op_r && offset_r[3:2] == 2'd1) ? wstrb_r : 
                    (state == `REFILL && !replace_way_r && ret_valid && count == 3'd1) ? 4'b1111 : 
                    4'b0000;
assign we_bank0_2 = (state == `LOOKUP && way0_hit && op_r && offset_r[3:2] == 2'd2) ? wstrb_r : 
                    (state == `REFILL && !replace_way_r && ret_valid && count == 3'd2) ? 4'b1111 : 
                    4'b0000;
assign we_bank0_3 = (state == `LOOKUP && way0_hit && op_r && offset_r[3:2] == 2'd3) ? wstrb_r : 
                    (state == `REFILL && !replace_way_r && ret_valid && count == 3'd3) ? 4'b1111 : 
                    4'b0000;
assign addr_bank0_0 = we_bank0_0 ? index_r : index;
assign addr_bank0_1 = we_bank0_1 ? index_r : index;
assign addr_bank0_2 = we_bank0_2 ? index_r : index;
assign addr_bank0_3 = we_bank0_3 ? index_r : index;
assign wdata_bank0_0 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd0) ? refill_data : ret_data) : wdata_r;
assign wdata_bank0_1 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd1) ? refill_data : ret_data) : wdata_r;
assign wdata_bank0_2 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd2) ? refill_data : ret_data) : wdata_r;
assign wdata_bank0_3 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd3) ? refill_data : ret_data) : wdata_r;

assign en_bank1_0 = 1'b1;
assign en_bank1_1 = 1'b1;
assign en_bank1_2 = 1'b1;
assign en_bank1_3 = 1'b1;
assign we_bank1_0 = (state == `LOOKUP && way1_hit && op_r && offset_r[3:2] == 2'd0) ? wstrb_r : 
                    (state == `REFILL && replace_way_r && ret_valid && count == 3'd0) ? 4'b1111 : 
                    4'b0000;
assign we_bank1_1 = (state == `LOOKUP && way1_hit && op_r && offset_r[3:2] == 2'd1) ? wstrb_r : 
                    (state == `REFILL && replace_way_r && ret_valid && count == 3'd1) ? 4'b1111 : 
                    4'b0000;
assign we_bank1_2 = (state == `LOOKUP && way1_hit && op_r && offset_r[3:2] == 2'd2) ? wstrb_r : 
                    (state == `REFILL && replace_way_r && ret_valid && count == 3'd2) ? 4'b1111 : 
                    4'b0000;
assign we_bank1_3 = (state == `LOOKUP && way1_hit && op_r && offset_r[3:2] == 2'd3) ? wstrb_r : 
                    (state == `REFILL && replace_way_r && ret_valid && count == 3'd3) ? 4'b1111 : 
                    4'b0000;
assign addr_bank1_0 = we_bank1_0 ? index_r : index;
assign addr_bank1_1 = we_bank1_1 ? index_r : index;
assign addr_bank1_2 = we_bank1_2 ? index_r : index;
assign addr_bank1_3 = we_bank1_3 ? index_r : index;
assign wdata_bank1_0 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd0) ? refill_data : ret_data) : wdata_r;
assign wdata_bank1_1 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd1) ? refill_data : ret_data) : wdata_r;
assign wdata_bank1_2 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd2) ? refill_data : ret_data) : wdata_r;
assign wdata_bank1_3 = state == `REFILL ? ((op_r && offset_r[3:2] == 2'd3) ? refill_data : ret_data) : wdata_r;

bank_ram way0_bank0_ram(
    .addra (addr_bank0_0),
    .clka  (clk),
    .dina  (wdata_bank0_0),
    .douta (way0_data[31:0]), //只在LOOKUP当拍有效
    .ena   (en_bank0_0),
    .wea   (we_bank0_0)
);
bank_ram way0_bank1_ram(
    .addra (addr_bank0_1),
    .clka  (clk),
    .dina  (wdata_bank0_1),
    .douta (way0_data[63:32]),
    .ena   (en_bank0_1),
    .wea   (we_bank0_1)
);
bank_ram way0_bank2_ram(
    .addra (addr_bank0_2),
    .clka  (clk),
    .dina  (wdata_bank0_2),
    .douta (way0_data[95:64]),
    .ena   (en_bank0_2),
    .wea   (we_bank0_2)
);
bank_ram way0_bank3_ram(
    .addra (addr_bank0_3),
    .clka  (clk),
    .dina  (wdata_bank0_3),
    .douta (way0_data[127:96]),
    .ena   (en_bank0_3),
    .wea   (we_bank0_3)
);

bank_ram way1_bank0_ram(
    .addra (addr_bank1_0),
    .clka  (clk),
    .dina  (wdata_bank1_0),
    .douta (way1_data[31:0]),
    .ena   (en_bank1_0),
    .wea   (we_bank1_0)
);
bank_ram way1_bank1_ram(
    .addra (addr_bank1_1),
    .clka  (clk),
    .dina  (wdata_bank1_1),
    .douta (way1_data[63:32]),
    .ena   (en_bank1_1),
    .wea   (we_bank1_1)
);
bank_ram way1_bank2_ram(
    .addra (addr_bank1_2),
    .clka  (clk),
    .dina  (wdata_bank1_2),
    .douta (way1_data[95:64]),
    .ena   (en_bank1_2),
    .wea   (we_bank1_2)
);
bank_ram way1_bank3_ram(
    .addra (addr_bank1_3),
    .clka  (clk),
    .dina  (wdata_bank1_3),
    .douta (way1_data[127:96]),
    .ena   (en_bank1_3),
    .wea   (we_bank1_3)
);

endmodule