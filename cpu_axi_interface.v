`define AXI_IDLE 2'd0
`define ARV 2'd1
`define RW 2'd2
`define WHANDLE 2'd3

module cpu_axi_interface
(
	input clk,
	input resetn,

	//inst sram-like, slave
	input         inst_req,
	input  [ 2:0] inst_size,
	input  [31:0] inst_addr,
	output        inst_rdy,
	output        inst_valid,
	output        inst_last,
	output [31:0] inst_rdata,

    //data sram-like, slave
	input         data_req,
	input         data_wr,
	input  [ 2:0] data_size,
	input  [31:0] data_addr,
    input  [ 3:0] data_wstrb,
	input  [31:0] data_wdata,
	output [31:0] data_rdata,
	output        data_addr_ok,
	output        data_data_ok,

    //axi, master
    //ar
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 3:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    //r
    input [ 3:0] rid,
    input [31:0] rdata,
    input [ 1:0] rresp,
    input        rlast,
    input        rvalid,
    output       rready,
    //aw
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 3:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    //w
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    //b
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready
);

reg [1:0] state;
reg [1:0] next_state;

reg [ 3:0] id_r;
reg [ 2:0] size_r;
reg [31:0] addr_r;
reg [ 3:0] wstrb_r;
reg [31:0] wdata_r;

reg [ 3:0] rid_r;
reg [31:0] rdata_r;

reg rdata_ok_r;
reg rlast_r;
reg wdata_ok_r;

reg has_waddr;
reg has_wdata;

//FSM����״̬����֤ÿ��ֻ����һ�����񣨶�/д����һ�ǽ��д�����أ����Ǳ��⿼����������д���񷵻ص�data_ok��˳����
always @(*) begin
    case (state)
        `AXI_IDLE: next_state = (data_req && data_wr) ? `WHANDLE : 
                                (data_req && !data_wr || inst_req) ? `ARV : 
                                `AXI_IDLE; //������״̬��addr_ok���ߣ�ֱ����req���ַ������������data_req����inst_rdy���ͣ����ȴ���data_req�������ȼ���д���� > ������ > ��ָ��
        `ARV: next_state = arready ? `RW : `ARV; //��������Ч״̬��arvalid���ߣ��ȴ�����ַ���䣨arready���ߣ�
        `RW: next_state = rlast ? `AXI_IDLE : `RW; //�����ݵȴ�״̬��rready���ߣ��ȴ������ݷ��أ�rvalid���ߣ��������ݷ��غ�һ�ζ��������
        `WHANDLE: next_state = bvalid ? `AXI_IDLE: `WHANDLE; //д����״̬��������awvalid��wvalid��aw��w���֣���b���֣�bvalid���ߣ������һ��д����
        default: next_state = `AXI_IDLE;
    endcase 
end
always @(posedge clk) begin
    if (!resetn)
        state <= `AXI_IDLE;
    else
        state <= next_state;
end

//��������
always @(posedge clk) begin
    if (state == `AXI_IDLE) begin
        if (data_req) begin
            id_r <= 4'd1;
            size_r <= data_size;
            addr_r <= data_addr;
            wstrb_r <= data_wstrb;
            wdata_r <= data_wdata;
        end
        else if (inst_req) begin
            id_r <= 4'd0;
            size_r <= inst_size;
            addr_r <= inst_addr;
        end
    end
end
//�������
always @(posedge clk) begin
    if (rvalid) begin
        rid_r <= rid;
        rdata_r <= rdata;
    end
end

//data_ok��������
always @(posedge clk) begin
    if (!resetn)
        rdata_ok_r <= 1'b0;
    else if (rvalid) //��ʾ���ݷ��ص���Ч�ź�
        rdata_ok_r <= 1'b1;
    else if (rdata_ok_r)
        rdata_ok_r <= 1'b0; //��һ�����
        
    if (!resetn)
        rlast_r <= 1'b0;
    else if (rlast)
        rlast_r <= 1'b1;
    else if (rlast_r)
        rlast_r <= 1'b0;
    
    if (!resetn)
        wdata_ok_r <= 1'b0;
    else if (bvalid) //��ʾд��Ӧ����Ч�ź�
        wdata_ok_r <= 1'b1;
    else if (wdata_ok_r)
        wdata_ok_r <= 1'b0; //��һ�����
end

//inst sram-like
assign inst_rdy   = !data_req && state == `AXI_IDLE;
assign inst_valid = rid_r == 4'd0 && rdata_ok_r;
assign inst_last  = rid_r == 4'd0 && rlast_r;
assign inst_rdata = rdata_r;

//data sram-like
assign data_addr_ok = state == `AXI_IDLE;
assign data_data_ok = rid_r == 4'd1 && rdata_ok_r || wdata_ok_r;
assign data_rdata = rdata_r;

//ar
assign arid = id_r;
assign araddr = addr_r;
assign arlen = size_r == 3'b100 ? 4'd3 : 4'd0;
assign arsize = size_r == 3'b100 ? 3'd2 : size_r;
assign arburst = 2'b01;
assign arlock = 2'd0;
assign arcache = 4'd0;
assign arprot = 3'd0;
assign arvalid = state == `ARV; //��arready���ֺ���

//r
assign rready = state == `RW;

//aw & w
always @(posedge clk) begin
    if (!resetn)
        has_waddr <= 1'b0;
    else if (state == `AXI_IDLE && data_req && data_wr) //д�����ַ��Ч��ֱ��aw����
        has_waddr <= 1'b1;
    else if (awvalid && awready)
        has_waddr <= 1'b0;
end
always @(posedge clk) begin
    if (!resetn)
        has_wdata <= 1'b0;
    else if (state == `AXI_IDLE && data_req && data_wr) //д����������Ч��ֱ��w����
        has_wdata <= 1'b1;
    else if (wvalid && wready)
        has_wdata <= 1'b0;    
end

assign awid = 4'd1;
assign awaddr = addr_r;
assign awlen = 4'd0;
assign awsize = size_r;
assign awburst = 2'b01;
assign awlock = 2'd0;
assign awcache = 4'd0;
assign awprot = 3'd0;
assign awvalid = has_waddr; //��awready���ֺ���

assign wid = 4'd1;
assign wdata = wdata_r;
assign wstrb = wstrb_r;
assign wlast = 1'b1;
assign wvalid = has_wdata; //��wready���ֺ���

//b
assign bready = state == `WHANDLE;

endmodule