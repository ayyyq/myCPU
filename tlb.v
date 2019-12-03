`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/29 21:21:23
// Design Name: 
// Module Name: tlb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tlb #
(
    parameter TLBNUM = 16
)
(
    input                       clk,
    
    // search port 0
    input  [              18:0] s0_vpn2,
    input                       s0_odd_page,
    input  [               7:0] s0_asid,
    output                      s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [              19:0] s0_pfn,
    output [               2:0] s0_c,
    output                      s0_d,
    output                      s0_v,
    
    // search port 1
    input  [              18:0] s1_vpn2,
    input                       s1_odd_page,
    input  [               7:0] s1_asid,
    output                      s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [              19:0] s1_pfn,
    output [               2:0] s1_c,
    output                      s1_d,
    output                      s1_v,
    
    // write port
    input                       we,
    input  [$clog2(TLBNUM)-1:0] w_index,
    input  [              18:0] w_vpn2,
    input  [               7:0] w_asid,
    input                       w_g,
    input  [              19:0] w_pfn0,
    input  [               2:0] w_c0,
    input                       w_d0,
    input                       w_v0,
    input  [              19:0] w_pfn1,
    input  [               2:0] w_c1,
    input                       w_d1,
    input                       w_v1,
    
    // read port
    input  [$clog2(TLBNUM)-1:0] r_index,
    output [              18:0] r_vpn2,
    output [               7:0] r_asid,
    output                      r_g,
    output [              19:0] r_pfn0,
    output [               2:0] r_c0,
    output                      r_d0,
    output                      r_v0,
    output [              19:0] r_pfn1,
    output [               2:0] r_c1,
    output                      r_d1,
    output                      r_v1
);

reg [18:0] tlb_vpn2 [TLBNUM-1:0];
reg [ 7:0] tlb_asid [TLBNUM-1:0];
reg        tlb_g    [TLBNUM-1:0];
reg [19:0] tlb_pfn0 [TLBNUM-1:0];
reg [ 2:0] tlb_c0   [TLBNUM-1:0];
reg        tlb_d0   [TLBNUM-1:0];
reg        tlb_v0   [TLBNUM-1:0];
reg [19:0] tlb_pfn1 [TLBNUM-1:0];
reg [ 2:0] tlb_c1   [TLBNUM-1:0];
reg        tlb_d1   [TLBNUM-1:0];
reg        tlb_v1   [TLBNUM-1:0];

wire [TLBNUM-1: 0] match0;
wire [TLBNUM-1: 0] match1;
genvar i;

//search port0
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin: loop0
        assign match0[i] = (s0_vpn2 == tlb_vpn2[i]) && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate
assign s0_found = match0 != 16'd0;
assign s0_index = ({$clog2(TLBNUM){match0[0]}} & 4'd0)
                | ({$clog2(TLBNUM){match0[1]}} & 4'd1)
                | ({$clog2(TLBNUM){match0[2]}} & 4'd2)
                | ({$clog2(TLBNUM){match0[3]}} & 4'd3)
                | ({$clog2(TLBNUM){match0[4]}} & 4'd4)
                | ({$clog2(TLBNUM){match0[5]}} & 4'd5)
                | ({$clog2(TLBNUM){match0[6]}} & 4'd6)
                | ({$clog2(TLBNUM){match0[7]}} & 4'd7)
                | ({$clog2(TLBNUM){match0[8]}} & 4'd8)
                | ({$clog2(TLBNUM){match0[9]}} & 4'd9)
                | ({$clog2(TLBNUM){match0[10]}} & 4'd10)
                | ({$clog2(TLBNUM){match0[11]}} & 4'd11)
                | ({$clog2(TLBNUM){match0[12]}} & 4'd12)
                | ({$clog2(TLBNUM){match0[13]}} & 4'd13)
                | ({$clog2(TLBNUM){match0[14]}} & 4'd14)
                | ({$clog2(TLBNUM){match0[15]}} & 4'd15);             
assign s0_pfn = s0_odd_page ? tlb_pfn1[s0_index] : tlb_pfn0[s0_index];
assign s0_c   = s0_odd_page ? tlb_c1[s0_index]   : tlb_c0[s0_index];
assign s0_d   = s0_odd_page ? tlb_d1[s0_index]   : tlb_d0[s0_index];
assign s0_v   = s0_odd_page ? tlb_v1[s0_index]   : tlb_v0[s0_index];

//search port1
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin: loop1
        assign match1[i] = (s1_vpn2 == tlb_vpn2[i]) && ((s1_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate
assign s1_found = match1 != 16'd0;                          
assign s1_index = ({$clog2(TLBNUM){match1[0]}} & 4'd0)
                | ({$clog2(TLBNUM){match1[1]}} & 4'd1)
                | ({$clog2(TLBNUM){match1[2]}} & 4'd2)
                | ({$clog2(TLBNUM){match1[3]}} & 4'd3)
                | ({$clog2(TLBNUM){match1[4]}} & 4'd4)
                | ({$clog2(TLBNUM){match1[5]}} & 4'd5)
                | ({$clog2(TLBNUM){match1[6]}} & 4'd6)
                | ({$clog2(TLBNUM){match1[7]}} & 4'd7)
                | ({$clog2(TLBNUM){match1[8]}} & 4'd8)
                | ({$clog2(TLBNUM){match1[9]}} & 4'd9)
                | ({$clog2(TLBNUM){match1[10]}} & 4'd10)
                | ({$clog2(TLBNUM){match1[11]}} & 4'd11)
                | ({$clog2(TLBNUM){match1[12]}} & 4'd12)
                | ({$clog2(TLBNUM){match1[13]}} & 4'd13)
                | ({$clog2(TLBNUM){match1[14]}} & 4'd14)
                | ({$clog2(TLBNUM){match1[15]}} & 4'd15);       
assign s1_pfn = s1_odd_page ? tlb_pfn1[s1_index] : tlb_pfn0[s1_index];
assign s1_c   = s1_odd_page ? tlb_c1[s1_index]   : tlb_c0[s1_index];
assign s1_d   = s1_odd_page ? tlb_d1[s1_index]   : tlb_d0[s1_index];
assign s1_v   = s1_odd_page ? tlb_v1[s1_index]   : tlb_v0[s1_index];

//write
always @(posedge clk) begin
    if (we) begin
        tlb_vpn2[w_index] <= w_vpn2;
        tlb_asid[w_index] <= w_asid;
        tlb_g[w_index]    <= w_g;
        tlb_pfn0[w_index] <= w_pfn0;
        tlb_c0[w_index]   <= w_c0;
        tlb_v0[w_index]   <= w_v0;
        tlb_d0[w_index]   <= w_d0;
        tlb_pfn1[w_index] <= w_pfn1;
        tlb_c1[w_index]   <= w_c1;
        tlb_d1[w_index]   <= w_d1;
        tlb_v1[w_index]   <= w_v1;
    end      
end

//read
assign r_vpn2 = tlb_vpn2[r_index];
assign r_asid = tlb_asid[r_index];
assign r_g    = tlb_g[r_index];
assign r_pfn0 = tlb_pfn0[r_index];
assign r_c0   = tlb_c0[r_index];
assign r_d0   = tlb_d0[r_index];
assign r_v0   = tlb_v0[r_index];
assign r_pfn1 = tlb_pfn1[r_index];
assign r_c1   = tlb_c1[r_index];
assign r_d1   = tlb_d1[r_index];
assign r_v1   = tlb_v1[r_index];

endmodule
