`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    output [`MS_TO_DS_FORWARD_BUS-1:0] ms_to_ds_forward_bus,
    input [63:0] mul_result, //新增
    input [31:0] div_result, //新增
    input [31:0] mod_result  //新增
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_load_op;   //添加用于存储是否进行访存指令
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [1:0]  es_mul_div_op; //新增乘除法信号
wire        mfhi;   //新增
wire        mflo;   //新增
wire        mthi;   //新增
wire        mtlo;   //新增
wire [31:0] ms_rs_value;
wire [2:0 ] ms_mem_op_type; //新增
wire [31:0] ms_rt_value;    //新增
wire [1:0] ms_lwl_or_lwr;  //新增
wire ms_is_mul;  //新增
assign {ms_is_mul      , //146:146 新增
        ms_lwl_or_lwr  , //145:144 新增
        ms_rt_value    , //143:112 新增
        ms_mem_op_type , //111:109新增
        ms_rs_value    , //108:77 新增 用于mthi、mtlo指令读rs寄存器的值
        es_mul_div_op  ,  //76:75 新增
        mfhi        ,     //74:74 新增
        mflo        ,     //73:73 新增
        mthi        ,     //72:72 新增
        mtlo        ,     //71:71 新增         
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;
wire [1:0] data_sram_addr_low_2;   //新增 访存地址的最低两位
wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire        dep_need_stall;
wire        forward_enable;
wire        dest_zero;
assign ms_load_op = ms_res_from_mem;

assign ms_to_ws_bus = {
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };
         //forward path             
assign dest_zero            = (ms_dest == 5'b0);
assign forward_enable       = ms_gr_we & ~dest_zero & ms_valid;
assign dep_need_stall       = ms_load_op && !ms_to_ws_valid;  //由于EXE级有访存指令所以和MEM有点区别
assign ms_to_ds_forward_bus = {dep_need_stall,  //38:38
                               forward_enable,  //37:37
                               ms_dest      ,  //36:32
                               ms_final_result  //31:0
                              };

//乘除法器
reg [31:0] hi;  //HI用于存放乘法结果的高32位和除法的余数
reg [31:0] lo;  //LO用于存放乘法结果的低32位和除法的商
wire        hi_write; //新增
wire        lo_write; //新增

assign hi_write = es_mul_div_op[1] | es_mul_div_op[0] | mthi;  //当执行除法、乘法、mthi时，触发写hi寄存器
assign lo_write = es_mul_div_op[1] | es_mul_div_op[0] | mtlo;  //当执行除法、乘法、mtlo时，触发写lo寄存器

//-----{HI/LO寄存器}begin
    //要写入HI的数据
    always @(posedge clk)
    begin
        if (hi_write)    //
        begin
            if (es_mul_div_op[0] )
            begin
                hi <= mul_result[63:32];
            end
            else if (es_mul_div_op[1]) 
            begin 
                hi <= mod_result;
            end  
            else if (mthi)
            begin
                hi <= ms_rs_value;
            end
        end
    end
    //要写入LO的数据
    always @(posedge clk)
    begin
        if (lo_write)  //
        begin
            if (es_mul_div_op[0])
            begin
                lo <= mul_result[31:0];
            end
            else if (es_mul_div_op[1]) 
            begin
                lo <= div_result; //
            end
            else if (mtlo)
            begin
                lo <= ms_rs_value;
            end
        end
    end
//-----{HI/LO寄存器}end
//*******************************************************************************


//assign ms_ready_go    = 1'b1;
assign ms_ready_go    = 1'b1 ;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end
wire [31:0] lwl_result;   //新增
wire [31:0] lwr_result;   //新增
assign data_sram_addr_low_2 = ms_alu_result[1:0];   //新增 

assign lwl_result = (data_sram_addr_low_2 == 2'b00) ? {data_sram_rdata[7:0],ms_rt_value[23:0]}   :   //新增
                    (data_sram_addr_low_2 == 2'b01) ? {data_sram_rdata[15:0],ms_rt_value[15:0]}  :
                    (data_sram_addr_low_2 == 2'b10) ? {data_sram_rdata[23:0] ,ms_rt_value[7:0]}  :
                                                       data_sram_rdata[31:0];             
assign lwr_result = (data_sram_addr_low_2 == 2'b00) ?  data_sram_rdata[31:0]                     :
                    (data_sram_addr_low_2 == 2'b01) ? {ms_rt_value[31:24],data_sram_rdata[31:8]} :   //新增
                    (data_sram_addr_low_2 == 2'b10) ? {ms_rt_value[31:16],data_sram_rdata[31:16]}:
                                                      {ms_rt_value[31:8] ,data_sram_rdata[31:24]};       

assign mem_result = (ms_mem_op_type[0] && data_sram_addr_low_2[1:0] == 2'b00) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[7]}},data_sram_rdata[7:0]}:
                    (ms_mem_op_type[0] && data_sram_addr_low_2[1:0] == 2'b01) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[15]}},data_sram_rdata[15:8]}: 
                    (ms_mem_op_type[0] && data_sram_addr_low_2[1:0] == 2'b10) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                    (ms_mem_op_type[0] && data_sram_addr_low_2[1:0] == 2'b11) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[31]}},data_sram_rdata[31:24]}:
                    (ms_mem_op_type[1] && data_sram_addr_low_2[1:0] == 2'b00) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[15]}},data_sram_rdata[15:0]}: 
                    (ms_mem_op_type[1] && data_sram_addr_low_2[1:0] == 2'b01) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[23]}},data_sram_rdata[23:8]}:
                    (ms_mem_op_type[1] && data_sram_addr_low_2[1:0] == 2'b10) ? {{24{(1'b0 | ms_mem_op_type[2]) & data_sram_rdata[31]}},data_sram_rdata[31:16]}:
                     ms_lwl_or_lwr[0] ? lwl_result : 
                     ms_lwl_or_lwr[1] ? lwr_result :
                                                      data_sram_rdata;
// assign mem_result = data_sram_rdata;

assign ms_final_result = mfhi ? hi :
                         mflo ? lo : 
                         ms_is_mul ? mul_result[31:0] :
                         ms_res_from_mem ? mem_result :
                                           ms_alu_result;

endmodule
