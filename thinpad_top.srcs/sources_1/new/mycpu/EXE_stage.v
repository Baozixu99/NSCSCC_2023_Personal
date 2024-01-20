`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output [`ES_TO_DS_FORWARD_BUS -1:0] es_to_ds_forward_bus,
    output [63:0] mul_result, //新增
    output [31:0] div_result, //新增
    output [31:0] mod_result,  //新增   
    output  wire  if_stall  ,
    output wire load_stall   
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_imm_zero;  //立即�?0扩展。新�?
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
wire [1:0]  es_mul_div_op; //新增乘除法信�?
wire        es_mul_div_sign; //新增乘除法符号信�?
wire        mfhi;   //新增
wire        mflo;   //新增
wire        mthi;   //新增
wire        mtlo;   //新增
wire [2:0 ] es_mem_op_type; //新增
wire [1:0] es_mem_size ; //新增
wire [ 1:0] sram_addr_low_2; //新增
wire [1:0] es_lwl_or_lwr;  //新增
wire [1:0] es_swl_or_swr;  //新增
wire   ex_is_mul; //新增

assign {ex_is_mul      ,  //153:153 新增
        es_swl_or_swr  ,  //152:151 新增
        es_lwl_or_lwr  ,  //150:149 新增
        es_mem_size    ,  //148:147 新增
        es_mem_op_type ,  //146:144 新增
        es_mul_div_op  ,  //143:142 新增
        es_mul_div_sign,  //141:141 新增
        mfhi        ,     //140:140 新增
        mflo        ,     //139:139 新增
        mthi        ,     //138:138 新增
        mtlo        ,     //137:137  新增       
        es_src2_is_imm_zero, //136:136 新增
        es_alu_op      ,  //135:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result ; //新增
wire        dep_need_stall ;
wire        forward_enable ;
wire        dest_zero      ;
assign  load_stall = (es_load_op || ex_is_mul) && es_valid;
assign es_res_from_mem = es_load_op;  
assign if_stall = es_res_from_mem && es_valid;  //新增

assign es_to_ms_bus = {ex_is_mul     ,   //146:146 新增  
                       es_lwl_or_lwr ,   //145:144 新增               
                       es_rt_value,      //143:112 新增
                       es_mem_op_type,   //111:109 新增
                       es_rs_value ,     //108:77 新增 用于mthi、mtlo指令读rs寄存器的�?
                       es_mul_div_op ,   //76:75 新增
                       mfhi        ,     //74:74 新增
                       mflo        ,     //73:73 新增
                       mthi        ,     //72:72 新增
                       mtlo        ,     //71:71  新增 
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32    //原为es_alu_result，修改为es_result
                       es_pc             //31:0
                      };
//forward path
assign dest_zero            = (es_dest == 5'b0); 
assign forward_enable       = es_gr_we & ~dest_zero & es_valid;
assign dep_need_stall       = es_load_op | es_valid | es_mul_enable; //新增 将原来的es_valid修改为es_div_enable又修改回去了
assign es_to_ds_forward_bus = {dep_need_stall ,  //38:38
                               forward_enable ,  //37:37
                               es_dest       ,  //36:32
                               es_result         //31:0  //原为es_alu_result，修改为es_result
                              };

assign es_ready_go    = 1'b1 && !div_stall; //新增div_stall
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm_zero ? {16'b0, es_imm[15:0]} :   //新增立即�?0扩展。es_src2_is_imm_zero ? {20'b0, es_imm[15:0]}  
                     es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} :  //立即数符号扩�?
                     es_src2_is_8   ? 32'd8 :        
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );


wire        div_stall; //新增
wire        es_div_enable; //新增
wire        div_complete; //新增
wire        es_mul_enable; //新增  

assign es_div_enable = es_mul_div_op[1] & es_valid; 
assign es_mul_enable = es_mul_div_op[0] | ex_is_mul; 
assign div_stall     = es_div_enable & ~div_complete; //等待除法执行完毕

mul u_mul(
    .mul_clk         (clk           ),
    .reset           (reset          ),
    .mul_signed      (es_mul_div_sign),
    .x               (es_alu_src1    ),
    .y               (es_alu_src2    ),
    .result          (mul_result     )
    );
 
assign es_result = es_alu_result ;
assign sram_addr_low_2 = {es_alu_result[1],es_alu_result[0]} ; //新增

wire [31:0] swl_result;
wire [31:0] swr_result;
assign swl_result = (sram_addr_low_2 == 2'b00) ? {24'b0,es_rt_value[31:24]} :
                    (sram_addr_low_2 == 2'b01) ? {16'b0,es_rt_value[31:16]} :
                    (sram_addr_low_2 == 2'b10) ? {8'b0,es_rt_value[31:8]}   :
                                                 {es_rt_value[31:0]};

assign swr_result = (sram_addr_low_2 == 2'b00) ? {es_rt_value[31:0]}        :
                    (sram_addr_low_2 == 2'b01) ? {es_rt_value[23:0],8'b0}   :
                    (sram_addr_low_2 == 2'b10) ? {es_rt_value[15:0],16'b0}  :
                                                 {es_rt_value[7:0],24'b0} ;     

wire [3:0] es_swl_wen =  (sram_addr_low_2==2'b11) ?  4'b1111 : 
                         (sram_addr_low_2==2'b10) ?  4'b0111 :
                         (sram_addr_low_2==2'b01) ?  4'b0011 :
                                                     4'b0001 ;

wire [3:0] es_swr_wen =  (sram_addr_low_2==2'b11) ?  4'b1000 : 
                         (sram_addr_low_2==2'b10) ?  4'b1100 :
                         (sram_addr_low_2==2'b01) ?  4'b1110 :
                                                     4'b1111 ;                                                     
                       
wire [3:0] es_sb_wen =  { sram_addr_low_2==2'b11  ,       //新增
                          sram_addr_low_2==2'b10  ,
                          sram_addr_low_2==2'b01  ,
                          sram_addr_low_2==2'b00} ;

wire [3:0] es_sh_wen =  { sram_addr_low_2==2'b10  ,     //新增
                          sram_addr_low_2==2'b10  ,
                          sram_addr_low_2==2'b00  ,
                          sram_addr_low_2==2'b00} ;

                      
wire es_mem_size_sw;//新增
assign es_mem_size_sw  = es_mem_we && !es_mem_size[0] && !es_mem_size[1] && !es_swl_or_swr[0] && !es_swl_or_swr[1];  //新增 判断为sw指令
assign data_sram_en    = (es_res_from_mem | es_mem_we ) && es_valid; //原为 1'b1

//assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;  //原data_sram_wen
assign data_sram_wen   = ( {4{es_mem_size[0]&&es_valid}} & es_sb_wen) |   //sb指令
                         ( {4{es_mem_size[1]&&es_valid}} & es_sh_wen) |   //sh指令
                         ( {4{es_mem_size_sw&&es_valid}} & 4'b1111)   | 
                         ( {4{es_swl_or_swr[0]&&es_valid}} & es_swl_wen) |
                         ( {4{es_swl_or_swr[1]&&es_valid}} & es_swr_wen);      
                         
assign data_sram_addr  = (es_result >= 32'hA0000000) ? (es_result - 32'hA0000000 ) : 
                         (es_result >= 32'h80000000) ? (es_result - 32'h80000000 ) :  //地址映射
                          es_result;  //原为es_alu_result，修改为es_result  //访存地址
//assign data_sram_wdata = es_rt_value;
assign data_sram_wdata = es_mem_size[0] ? {4{es_rt_value[7:0]}} :
                         es_mem_size[1] ? {2{es_rt_value[15:0]}}:
                         es_swl_or_swr[0] ? swl_result  : 
                         es_swl_or_swr[1] ? swr_result  :
                                             es_rt_value;

endmodule
