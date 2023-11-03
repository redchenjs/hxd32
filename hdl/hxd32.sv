/*
 * hxd32.sv
 *
 *  Created on: 2020-08-02 16:55
 *      Author: Jack Chen <redchenjs@live.com>
 */

import pc_op_pkg::*;

module hxd32 #(
    parameter XLEN = 32,

    parameter ADDR_WIDTH =  3,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH =  4
) (
    input logic aclk_i,
    input logic aresetn_i,

    /**********************************************
        ibus read interface (axi4-lite master)
    **********************************************/

    // read address channel
    input  logic [ADDR_WIDTH-1:0] ibus_araddr_i,
    input  logic                  ibus_arprot_i,
    input  logic                  ibus_arvalid_i,
    output logic                  ibus_arready_o,

    // read data channel
    output logic [DATA_WIDTH-1:0] ibus_rdata_o,
    output logic            [1:0] ibus_rresp_o
    output logic                  ibus_rvalid_o,
    input  logic                  ibus_rready_i,

    /**********************************************
        dbus write interface (axi4-lite master)
    **********************************************/

    // write address channel
    input  logic [ADDR_WIDTH-1:0] dbus_awaddr_i,
    input  logic                  dbus_awprot_i,
    input  logic                  dbus_awvalid_i,
    output logic                  dbus_awready_o,

    // write data channel
    input  logic         [DATA_WIDTH-1:0] dbus_wdata_i,
    input  logic [$clog2(DATA_WIDTH)-1:0] dbus_wstrb_i,
    input  logic                          dbus_wvalid_i,
    output logic                          dbus_wready_o,

    // write response channel
    output logic [1:0] dbus_bresp_o,
    output logic       dbus_bvalid_o,
    input  logic       dbus_bready_i,

    /**********************************************
        dbus read interface (axi4-lite master)
    **********************************************/

    // read address channel
    input  logic [ADDR_WIDTH-1:0] dbus_araddr_i,
    input  logic                  dbus_arprot_i,
    input  logic                  dbus_arvalid_i,
    output logic                  dbus_arready_o,

    // read data channel
    output logic [DATA_WIDTH-1:0] dbus_rdata_o,
    output logic            [1:0] dbus_rresp_o
    output logic                  dbus_rvalid_o,
    input  logic                  dbus_rready_i,

    /**********************************************
                    debug signals 
    **********************************************/

    // control interface
    input  logic            inst_valid_i,
    output logic            inst_error_o,
    output logic [XLEN-1:0] inst_retired_o
);

logic [XLEN-1:0] inst_data;
logic            inst_error;
logic [XLEN-1:0] inst_retired;

logic       pc_wr_en;
logic [1:0] pc_wr_sel;
logic [1:0] pc_inc_sel;

logic [XLEN-1:0] pc_data;

logic            alu_comp;
logic [XLEN-1:0] alu_data;

logic [1:0] alu_a_sel;
logic [1:0] alu_b_sel;

logic [2:0] alu_comp_sel;

logic       alu_op_0_sel;
logic [2:0] alu_op_1_sel;

logic       dram_wr_en;
logic [2:0] dram_wr_sel;
logic [2:0] dram_rd_sel;

logic       rd_wr_en;
logic [1:0] rd_wr_sel;
logic [4:0] rd_wr_addr;

logic [4:0] rs1_rd_addr;
logic [4:0] rs2_rd_addr;

logic [XLEN-1:0] rs1_rd_data;
logic [XLEN-1:0] rs2_rd_data;
logic [XLEN-1:0] imm_rd_data;

logic [3:0] dram_wr_byte_en;

logic            reg_wr_en;
logic      [4:0] reg_wr_addr;
logic [XLEN-1:0] reg_wr_data;

/* pipeline regs */

logic       pc_wr_en_r1;
logic [1:0] pc_wr_sel_r1;
logic [1:0] pc_inc_sel_r1;

assign inst_data = pc_inc_sel_r1[1] | ~pc_wr_en_r1 | (pc_wr_sel_r1 != PC_WR_NEXT) ? (pc_inc_sel_r1[0] ? 32'h0001_0001 : 32'h0000_0013) : iram_rd_data_i;

assign iram_rd_addr_io = rst_n_i ? pc_data : {XLEN{1'bz}};
assign dram_rd_addr_io = rst_n_i ? alu_data : {XLEN{1'bz}};

assign dram_wr_addr_io    = rst_n_i ? alu_data : {XLEN{1'bz}};
assign dram_wr_data_io    = rst_n_i ? rs2_rd_data : {XLEN{1'bz}};
assign dram_wr_byte_en_io = rst_n_i ? dram_wr_byte_en : {4{1'bz}};

assign inst_error_o = inst_error;

if_top #(
    .XLEN(XLEN)
) if_top (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),

    .pc_wr_en_i(pc_wr_en & ~inst_error),
    .pc_wr_sel_i(pc_wr_sel),
    .pc_inc_sel_i(pc_inc_sel),

    .alu_data_i(alu_data),

    .pc_data_o(pc_data)
);

id_top #(
    .XLEN(XLEN)
) id_top (
    .alu_comp_i(alu_comp),

    .pc_inc_sel_r_i(pc_inc_sel_r1),

    .inst_data_i(inst_data),

    .pc_wr_en_o(pc_wr_en),
    .pc_wr_sel_o(pc_wr_sel),
    .pc_inc_sel_o(pc_inc_sel),

    .alu_a_sel_o(alu_a_sel),
    .alu_b_sel_o(alu_b_sel),

    .alu_comp_sel_o(alu_comp_sel),

    .alu_op_0_sel_o(alu_op_0_sel),
    .alu_op_1_sel_o(alu_op_1_sel),

    .dram_wr_en_o(dram_wr_en),
    .dram_wr_sel_o(dram_wr_sel),
    .dram_rd_sel_o(dram_rd_sel),

    .rd_wr_en_o(rd_wr_en),
    .rd_wr_sel_o(rd_wr_sel),
    .rd_wr_addr_o(rd_wr_addr),

    .rs1_rd_addr_o(rs1_rd_addr),
    .rs2_rd_addr_o(rs2_rd_addr),

    .imm_rd_data_o(imm_rd_data)
);

always_ff @(posedge clk_i or negedge rst_n_i)
begin
    if (!rst_n_i) begin
        pc_wr_en_r1   <= 'b0;
        pc_wr_sel_r1  <= 'b0;
        pc_inc_sel_r1 <= 'b0;
    end else begin
        pc_wr_en_r1   <= pc_wr_en;
        pc_wr_sel_r1  <= pc_wr_sel;
        pc_inc_sel_r1 <= pc_inc_sel;
    end
end

regfile #(
    .XLEN(XLEN)
) regfile (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),

    .rd_wr_en_i(reg_wr_en),
    .rd_wr_addr_i(reg_wr_addr),
    .rd_wr_data_i(reg_wr_data),

    .rs1_rd_addr_i(rs1_rd_addr),
    .rs2_rd_addr_i(rs2_rd_addr),

    .rs1_rd_data_o(rs1_rd_data),
    .rs2_rd_data_o(rs2_rd_data)
);

ex_top #(
    .XLEN(XLEN)
) ex_top (
    .pc_data_i(pc_data_r1),

    .rs1_rd_data_i(rs1_rd_data),
    .rs2_rd_data_i(rs2_rd_data),
    .imm_rd_data_i(imm_rd_data),

    .alu_a_sel_i(alu_a_sel),
    .alu_b_sel_i(alu_b_sel),

    .alu_comp_sel_i(alu_comp_sel),

    .alu_op_0_sel_i(alu_op_0_sel),
    .alu_op_1_sel_i(alu_op_1_sel),

    .alu_comp_o(alu_comp),
    .alu_data_o(alu_data)
);

ma_top #(
    .XLEN(XLEN)
) ma_top (
    .dram_wr_en_i(dram_wr_en),
    .dram_wr_sel_i(dram_wr_sel),

    .dram_wr_byte_en_o(dram_wr_byte_en)
);

wb_top #(
    .XLEN(XLEN)
) wb_top (
    .rd_wr_en_i(rd_wr_en),
    .rd_wr_sel_i(rd_wr_sel),
    .rd_wr_addr_i(rd_wr_addr),

    .rd_wr_en_r_i(rd_wr_en_r1),
    .rd_wr_sel_r_i(rd_wr_sel_r1),
    .rd_wr_addr_r_i(rd_wr_addr_r1),

    .pc_data_i(pc_data_r1),

    .alu_data_i(alu_data),

    .dram_rd_sel_i(dram_rd_sel),
    .dram_rd_data_i(dram_rd_data_i),

    .dram_rd_sel_r_i(dram_rd_sel_r1),

    .reg_wr_en_o(reg_wr_en),
    .reg_wr_addr_o(reg_wr_addr),
    .reg_wr_data_o(reg_wr_data)
);

always_ff @(posedge clk_i or negedge rst_n_i)
begin
    if (!rst_n_i) begin
        inst_error <= 1'b0;
    end else begin
        inst_error <= (inst_data[15:0] == 16'h0000) ? 1'b1 : inst_error;
    end
end

endmodule
