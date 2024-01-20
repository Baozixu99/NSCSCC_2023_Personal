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
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input              IF_over,      //对于分支指令，需要该信号
        //from es forward path
    input  [`ES_TO_DS_FORWARD_BUS -1:0] es_to_ds_forward_bus,
    input  [`MS_TO_DS_FORWARD_BUS -1:0] ms_to_ds_forward_bus,
    input  [`MS_TO_DS_FORWARD_BUS-1:0] ws_to_ds_forward_bus,
    output  wire forward_stall ,  //阻塞信号传给取指阶段
    input wire load_stall

);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire [1:0]  mul_div_op; //新增乘除法信号
wire        mul_div_sign; //新增乘除法符号信号
wire        mfhi;   //新增
wire        mflo;   //新增
wire        mthi;   //新增
wire        mtlo;   //新增
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_imm_zero; //立即数0扩展。新增
wire        src2_is_8;
wire        res_from_mem;
wire [2:0]  mem_op_type;  //新增访存操作类型的变量，用来区分lb\lbu与lh\lhu的区别，mem_op_type[0]为lb\lbu,mem_op_type[1]为lh\lhu。
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire [1:0]  mem_size;
wire [1:0] lwl_or_lwr;  //新增
wire [1:0] swl_or_swr;  //新增

wire        inst_need_rs;   //是否需要读rs
wire        inst_need_rt;   //是否需要读rt

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_add;  //新增add指令      
wire        inst_subu;
wire        inst_sub;  //新增sub指令   
wire        inst_slt;
wire        inst_slti; //新增slti指令
wire        inst_sltiu; //新增sltiu指令
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_andi; //新增
wire        inst_ori;  //新增
wire        inst_xori; //新增
wire        inst_sll;  
wire        inst_sllv; //新增
wire        inst_srl;
wire        inst_srlv; //新增
wire        inst_sra;
wire        inst_srav; //新增
wire        inst_addiu;
wire        inst_addi;  //新增addi指令   
wire        inst_lui;
wire        inst_lw;
wire        inst_lwl;  //新增
wire        inst_lwr;  //新增
wire        inst_swl;  //新增
wire        inst_swr;  //新增  
wire        inst_lb;   //新增
wire        inst_lbu;  //新增
wire        inst_lh;   //新增
wire        inst_lhu;  //新增  
wire        inst_sw;
wire        inst_sb;   //新增
wire        inst_sh;   //新增   
wire        inst_beq;
wire        inst_bne;
wire        inst_bgez;  //新增
wire        inst_bgtz;  //新增
wire        inst_blez;  //新增
wire        inst_bltz;  //新增
wire        inst_bltzal;//新增
wire        inst_bgezal;//新增
wire        inst_jal;
wire        inst_j;     //新增
wire        inst_jr;
wire        inst_jalr; //新增  
wire        inst_mul; //新增
wire        inst_mult;  //新增有符号乘法
wire        inst_multu; //新增无符号乘法
wire        inst_div;   //新增有符号除法
wire        inst_divu;  //新增无符号除法
wire        inst_mfhi;  //新增读hi寄存器，并写入通用寄存器
wire        inst_mflo;  //新增读lo寄存器，并写入通用寄存器
wire        inst_mthi;  //新增读通用寄存器，并写入hi寄存器
wire        inst_mtlo;  //新增读通用寄存器，并写入lo寄存器
  

wire        ms_forward_enable;
wire [ 4:0] ms_forward_reg;
wire [31:0] ms_forward_data;
wire        ms_dep_need_stall;
wire        es_dep_need_stall;
wire        es_forward_enable;
wire [ 4:0] es_forward_reg;
wire [31:0] es_forward_data;
wire        ws_dep_need_stall;
wire        ws_forward_enable;
wire [ 4:0] ws_forward_reg;
wire [31:0] ws_forward_data;
wire        rf1_forward_stall;
wire        rf2_forward_stall;
wire        br_need_reg_data;


wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
//assign br_bus       = {br_taken,br_target};
assign br_bus       = {br_stall,br_taken,br_target};
wire br_stall = load_stall; 
assign ds_to_es_bus = {is_mul      ,  //153:153 新增 
                       swl_or_swr  ,  //152:151 新增
                       lwl_or_lwr  ,  //150:149 新增
                       mem_size    ,  //148:147 新增
                       mem_op_type ,  //146:144 新增
                       mul_div_op  ,  //143:142 新增
                       mul_div_sign,  //141:141 新增
                       mfhi        ,  //140:140 新增
                       mflo        ,  //139:139 新增
                       mthi        ,  //138:138 新增
                       mtlo        ,  //137:137  新增                    
                       src2_is_imm_zero, //136:136 新增
                       alu_op      ,  //135:124
                       load_op     ,  //123:123
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

wire        inst_jbr;   //是否有分支跳转指令
assign      inst_jbr = inst_jal | inst_beq | inst_bne | inst_jr | inst_bgez | inst_bgtz | inst_blez | inst_bltz | inst_j | inst_bltzal | inst_bgezal | inst_jalr ; //新增

//assign ds_ready_go    = ds_valid & ~rf1_forward_stall & ~rf2_forward_stall & (~inst_jbr | (inst_jbr & IF_over));
assign ds_ready_go     = !load_stall ;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
   //第一个bug
    if(reset) begin
        ds_valid = 1'b0;
    end
    if(ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    //
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

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];  //新增add
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];  //新增sub
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00]; //新增
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00]; //新增
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00]; //新增
assign inst_addiu  = op_d[6'h09];
assign inst_addi   = op_d[6'h08];  //新增
assign inst_slti   = op_d[6'h0a];  //新增
assign inst_sltiu  = op_d[6'h0b];  //新增
assign inst_andi   = op_d[6'h0c];  //新增
assign inst_ori    = op_d[6'h0d];  //新增
assign inst_xori   = op_d[6'h0e];  //新增
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_lwl    = op_d[6'h22];  //新增
assign inst_lwr    = op_d[6'h26];  //新增
assign inst_lb     = op_d[6'h20]; //新增
assign inst_lbu    = op_d[6'h24]; //新增
assign inst_lh     = op_d[6'h21]; //新增
assign inst_lhu    = op_d[6'h25]; //新增
assign inst_sw     = op_d[6'h2b];
assign inst_swl    = op_d[6'h2a]; //新增
assign inst_swr    = op_d[6'h2e]; //新增
assign inst_sb     = op_d[6'h28]; //新增
assign inst_sh     = op_d[6'h29]; //新增
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];  //新增
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];  //新增
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];  //新增
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];  //新增
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];  //新增
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];  //新增
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];  //新增
assign inst_jal    = op_d[6'h03];
assign inst_j      = op_d[6'h02]; //新增

assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mul    = op_d[6'h1c] & func_d[6'h02] & sa_d[5'h00] ; //新增
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00]; //新增
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00]; //新增
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00]; //新增
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00]; //新增
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00]; //新增
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00]; //新增
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00]; //新增
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00]; //新增

assign load_op = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr; //读数据存储器（RAM)指令
  
  
assign alu_op[ 0] = inst_addu   | 
                   inst_addiu   | 
                   inst_lw      | 
                   inst_sw      | 
                   inst_jal     | 
                   inst_add     | 
                   inst_addi    | 
                   inst_bltzal  |
                   inst_bgezal  | 
                   inst_jalr    | 
                   inst_lb      | 
                   inst_lbu     |
                   inst_lh      |  
                   inst_lhu     | 
                   inst_sb      | 
                   inst_sh      |
                   inst_lwl     |
                   inst_lwr     |
                   inst_swl     |
                   inst_swr   ; //新增
assign alu_op[ 1] = inst_subu | inst_sub;  //添加inst_sub
assign alu_op[ 2] = inst_slt  | inst_slti;  //添加inst_slti
assign alu_op[ 3] = inst_sltu | inst_sltiu; //添加sltiu
assign alu_op[ 4] = inst_and  | inst_andi;  //新增andi
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or  | inst_ori;   //新增ori
assign alu_op[ 7] = inst_xor | inst_xori; //新增xori
assign alu_op[ 8] = inst_sll | inst_sllv; //新增inst_sllv
assign alu_op[ 9] = inst_srl | inst_srlv; //新增inst_srlv
assign alu_op[10] = inst_sra | inst_srav; //新增inst_srav
assign alu_op[11] = inst_lui;

//乘除法
wire is_mul;
assign is_mul = inst_mul;  //新增
assign mul_div_op[0] = inst_mult | inst_multu ; //新增  mul_div_op需传递到EXE级
assign mul_div_op[1] = inst_div  | inst_divu; //新增
assign mul_div_sign  = inst_mult  | inst_div | inst_mul ; //新增  并传递到EXE级

assign mfhi = inst_mfhi; //新增  传递到EXE级
assign mflo = inst_mflo; //新增  传递到EXE级
assign mthi = inst_mthi; //新增  传递到EXE级
assign mtlo = inst_mtlo; //新增  传递到EXE级

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_bltzal | inst_bgezal | inst_jalr; //新增
assign src2_is_imm  = inst_addiu | inst_lui | inst_lw | inst_sw | inst_slti | inst_sltiu | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lwl | inst_lwr | inst_swl | inst_swr;//立即数符号扩展。添加slti、sltiu、
assign src2_is_imm_zero = inst_andi | inst_ori | inst_xori;//立即数0扩展。新增
assign src2_is_8    = inst_jal | inst_bltzal | inst_bgezal | inst_jalr; //新增;
assign res_from_mem = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl |inst_lwr;  //和load_op重复了
assign dst_is_r31   = inst_jal | inst_bltzal | inst_bgezal; //新增;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;//添加slti、sltiu、inst_andi、inst_ori、inst_xori
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_j & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr ; //坑不用加上inst_bltzal和inst_bgezal(因为他俩的exe、mem、wb和jal一样)//增加~inst_j指令(通过观察inst_jr可知，书上只让关注inst_jal), //用于控制是否前递的信号，在执行分支、跳转指令的时候由于不是顺序执行无法提前计算出目标地址，也就无法前递。
assign mem_we       = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr; //写数据存储器（RAM)指令
assign mem_op_type[0] = inst_lb | inst_lbu;  //新增  读一个字节
assign mem_op_type[1] = inst_lh | inst_lhu;  //新增  读两个字节
assign mem_op_type[2] = inst_lb | inst_lh;  //有符号扩展
assign mem_size[0]    = inst_sb; //新增
assign mem_size[1]    = inst_sh; //新增
//assign mem_op_tyoe[3] = inst_lbu| inst_lhu; 无符号扩展
assign lwl_or_lwr[0] = inst_lwl;
assign lwl_or_lwr[1] = inst_lwr;
assign swl_or_swr[0] = inst_swl;
assign swl_or_swr[1] = inst_swr;

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

assign {es_dep_need_stall,      //控制es级是否阻塞
        es_forward_enable, 
        es_forward_reg   ,
        es_forward_data
       } = es_to_ds_forward_bus;
assign {ms_dep_need_stall,      //控制ms级是否阻塞
        ms_forward_enable, 
        ms_forward_reg   ,
        ms_forward_data
       } = ms_to_ds_forward_bus;
assign {ws_dep_need_stall, 
        ws_forward_enable,
        ws_forward_reg   ,
        ws_forward_data
       } = ws_to_ds_forward_bus;

//inst_need_rs用于判断是否需要读rs //用于前递
assign inst_need_rs = inst_addu    |   //rd,rs,rt
                      inst_add     |   //rd,rs,rt 新增
                      inst_addiu   |   //rt,rs,imm  
                      inst_addi    |   //rt,rs,imm 新增
                      inst_slti    |   //rt,rs,imm 新增
                      inst_sltiu   |   //rt,rs,imm 新增
                      inst_sllv    |   //rd,rt,rs 新增
                      inst_srlv    |   //rd,rt,rs 新增
                      inst_srav    |   //rd,rt,rs 新增
                      inst_subu    |   //rd,rs,rt
                      inst_sub     |   //rd,rs,rt 新增
                      inst_slt     |   //rd,rs,rt
                      inst_sltu    |   //rd,rs,rt                      
                      inst_and     |   //rd,rs,rt
                      inst_or      |   //rd,rs,rt
                      inst_xor     |   //rd,rs,rt
                      inst_nor     |   //rd,rs,rt
                      inst_andi    |   //rt,rs,imm 新增
                      inst_ori     |   //rt,rs,imm 新增
                      inst_xori    |   //rt,rs,imm 新增
                      inst_sw      |   //rt,offset(base)  
                      inst_swl     |   //rt,offeset(base) 新增  
                      inst_swr     |   //rt,offeset(base) 新增 
                      inst_sb      |   //rt,offset 新增 
                      inst_sh      |   //rt,offset 新增  
                      inst_beq     |   //rs,rt,offset 
                      inst_bne     |   //rs,rt,offset 
                      inst_bgez    |   //rs,offset 新增   
                      inst_bgtz    |   //rs,offset 新增   
                      inst_blez    |   //rs,offset 新增   
                      inst_bltz    |   //rs,offset 新增   
                      inst_bltzal  |   //rs,offset 新增 
                      inst_bgezal  |   //rs,offset 新增  
                      inst_lw      |   //rt,offset(rs)
                      inst_lwl     |   //rt,offset(rs) 新增
                      inst_lwr     |   //rt,offset(rs) 新增
                      inst_lb      |   //rt,offset(rs)
                      inst_lbu     |   //rt,offset(rs)
                      inst_lh      |   //rt,offset(rs)
                      inst_lhu     |   //rt,offset(rs)
                      inst_jalr    |   //rd,rs 新增                                        
                      inst_jr      |   //rs,rt 新增
                      inst_mult    |   //rs,rt 新增
                      inst_multu   |   //rs,rt 新增
                      inst_mul     |   //rs，rt 新增
                      inst_div     |   //rs,rt 新增
                      inst_divu    |   //rs,rt 新增
                      inst_mthi    |   //rs 新增
                      inst_mtlo    ;   //rs 新增
                      
                      //jal target
assign inst_need_rt = inst_addu    |   //rd,rs,rt
                      inst_add     |   //rd,rs,rt 新增
                      inst_addiu   |   //rt,rs,imm
                      inst_addi    |   //rt,rs,imm 新增
                      inst_slti    |   //rt,rs,imm 新增
                      inst_sltiu   |   //rt,rs,imm 新增
                      inst_sllv    |   //rd,rt,rs 新增
                      inst_srlv    |   //rd,rt,rs 新增
                      inst_srav    |   //rd,rt,rs 新增
                      inst_subu    |   //rd,rs,rt
                      inst_sub     |   //rd,rs,rt 新增                      
                      inst_slt     |   //rd,rs,rt
                      inst_sltu    |   //rd,rs,rt                      
                      inst_and     |   //rd,rs,rt
                      inst_or      |   //rd,rs,rt
                      inst_xor     |   //rd,rs,rt
                      inst_nor     |   //rd,rs,rt
                      inst_andi    |   //rt,rs,imm 新增
                      inst_ori     |   //rt,rs,imm 新增
                      inst_xori    |   //rt,rs,imm 新增
                      inst_jalr    |   //rd,rs 新增
                      inst_lui     |   //rt,imm
                      inst_sll     |   //rd,rt,sa
                      inst_sra     |   //rd,rt,sa
                      inst_lw      |   //rt,offset
                      inst_lwl     |   //rt,offset(rs) 新增
                      inst_lwr     |   //rt,offset(rs) 新增
                      inst_lb      |   //rt,offset
                      inst_lbu     |   //rt,offset
                      inst_lh      |   //rt,offset
                      inst_lhu     |   //rt,offset
                      inst_sw      |   //rt,offset(base)
                      inst_swl     |   //rt,offeset(base) 新增  
                      inst_swr     |   //rt,offeset(base) 新增
                      inst_sb      |   //rt,offset 新增 
                      inst_sh      |   //rt,offset 新增     
                      inst_beq     |   //rs,rt,offset 
                      inst_bne     |
                      inst_mult    |   //rs,rt 新增
                      inst_multu   |   //rs,rt 新增
                      inst_mul     |   //rs，rt 新增
                      inst_div     |   //rs,rt 新增
                      inst_divu     ;  //rs,rt 新增   

assign br_need_reg_data = inst_jbr;
assign forward_stall =(rf1_forward_stall || rf2_forward_stall) && ds_valid;

wire [31:0] rs_value_forward_es;
wire [31:0] rt_value_forward_es;

//exe stage first forward    选择器选择前递的数据且有优先顺序EXE>MEM>WB
//inst_need_rs也可以不用判断，因为rf_raddr1 == es_forward_reg如果相同且es_forward_enable为1那么就一定要把前递过来的数据赋给rs_value
assign {rf1_forward_stall, rs_value, rs_value_forward_es} =  ((rf_raddr1 == es_forward_reg) && es_forward_enable && inst_need_rs) ? {es_dep_need_stall, es_forward_data, es_forward_data} :   
                                                             ((rf_raddr1 == ms_forward_reg) && ms_forward_enable && inst_need_rs) ? {ms_dep_need_stall || br_need_reg_data , ms_forward_data, rf_rdata1} :
                                                             ((rf_raddr1 == ws_forward_reg) && ws_forward_enable && inst_need_rs) ? {ws_dep_need_stall,ws_forward_data, ws_forward_data} :  
                                                                                                               {1'b0, rf_rdata1, rf_rdata1}; 
//inst_need_rt同理上面inst_need_rs
assign {rf2_forward_stall, rt_value, rt_value_forward_es} = ((rf_raddr2 == es_forward_reg) && es_forward_enable && inst_need_rt) ? {es_dep_need_stall, es_forward_data, es_forward_data} :
                                                            ((rf_raddr2 == ms_forward_reg) && ms_forward_enable && inst_need_rt) ? {ms_dep_need_stall || br_need_reg_data, ms_forward_data, rf_rdata2} :
                                                            ((rf_raddr2 == ws_forward_reg) && ws_forward_enable && inst_need_rt) ? {ws_dep_need_stall,ws_forward_data, ws_forward_data} :
                                                                                                              {1'b0, rf_rdata2, rf_rdata2};


assign rs_eq_rt = (rs_value == rt_value);
assign rs_geq_zero = !rs_value[31];
assign rs_gt_zero  = !rs_value[31] & (|rs_value[30:0]);

assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    &&  !rs_eq_rt
                   || inst_bgez   &&  rs_geq_zero //新增   $signed(rs_value)
                   || inst_bgtz   &&  rs_gt_zero //新增
                   || inst_blez   &&  !rs_gt_zero //新增
                   || inst_bltz   &&  !rs_geq_zero //新增
                   || inst_bltzal &&  !rs_geq_zero //新增
                   || inst_bgezal &&  rs_geq_zero//新增
                   || inst_jal
                   || inst_j    //新增
                   || inst_jalr //新增
                   || inst_jr
                  ) && ds_valid;
/*
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_bgez && ($signed(rs_value_forward_es) >= 0 ) //新增   $signed(rs_value)
                   || inst_bgtz && ($signed(rs_value_forward_es) >  0 ) //新增
                   || inst_blez && ($signed(rs_value_forward_es) <= 0 ) //新增
                   || inst_bltz && ($signed(rs_value_forward_es) <  0 ) //新增
                   || inst_bltzal && ($signed(rs_value_forward_es) < 0) //新增
                   || inst_bgezal && ($signed(rs_value_forward_es) >=0) //新增
                   || inst_jal
                   || inst_j    //新增
                   || inst_jalr //新增
                   || inst_jr
                  ) && ds_valid;
                  */
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) : //新增
                   (inst_jr  || inst_jalr)              ? rs_value : //新增
                  /*inst_jal | inst_j*/              {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule
