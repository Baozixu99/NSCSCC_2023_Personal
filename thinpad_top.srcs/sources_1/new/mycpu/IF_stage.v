`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                           fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output reg        IF_over    ,// IF模块执行完成
    input wire  forward_stall    ,   //阻塞信号
    input wire if_stall 
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire         br_taken;
wire         br_stall;
wire [ 31:0] br_target;
//assign {br_taken,br_target} = br_bus;
assign {br_stall,br_taken,br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc; 

always @(posedge clk)
    begin
        if (br_stall)      //forward_stall
        begin
            fs_inst_r <= inst_sram_rdata;
            inst_buff_enable  <= 1'b1;
        end
        else
        begin
            inst_buff_enable <=1'b0;
        end
    end
// IF stage
assign fs_ready_go    = 1'b1;
//assign fs_ready_go    = 1'b1  && !if_stall ;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin ;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'h7ffffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end


reg [31:0] fs_inst_r;
reg [31:0] fs_inst_brtaken;
reg [31:0] fs_inst_r_buffer;
reg need_stall;
reg inst_buff_enable;
reg [1:0] stall_count;
reg [1:0] br_count;
// 判断是否连续阻塞了两个节拍
wire is_two_stalls = (stall_count == 2'b10);
wire br_is_one_stalls = (br_count == 2'b01);
// 当计数器值达到2时，将临时寄存器中的值赋给fs_inst_r
//储存inst_sram_rdata，阻塞持续两排和br_traken持续两排及以上时，会出现丢指令的情况
/*
always @(posedge clk)
    begin
        if (forward_stall  )      //forward_stall
        begin
            fs_inst_r <= inst_sram_rdata;
            need_stall <= forward_stall;
            stall_count <= stall_count + 1;
            inst_buff_enable  <= 1'b1;
        end
        else
        begin
            need_stall <= 1'b0;
            stall_count <= 2'b0;
            inst_buff_enable <=1'b0;
        end
        if (br_taken)      //
        begin
            fs_inst_brtaken <= inst_sram_rdata;
            br_count <= br_count + 1;
        end 
        else
        begin
            br_count <= 2'b0;
        end
        if (if_stall)
        begin
            fs_inst_r <= inst_sram_rdata;
            inst_buff_enable  <= 1'b1;
        end
        if(!forward_stall && !if_stall )
        begin
           fs_inst_r <= inst_sram_rdata; 
        end
    end
    
always @(posedge clk) begin
    // 第二个辅助寄存器在上一个时钟周期的时钟上升沿时锁存 inst_sram_rdata 的值
        fs_inst_r_buffer <= fs_inst_r;
end

*/




//-----{IF执行完成}begin
    //由于指令rom为同步读写的,
    //取数据时，有一拍延时
    //即发地址的下一拍时钟才能得到对应的指令
    //故取指模块需要两拍时间
    //故每次PC刷新，IF_over都要置0
    //然后将IF_valid锁存一拍即是IF_over信号
    //与sourcecode代码中不一样的地方是将if (~reset || fs_allowin) 改成了if (reset || fs_allowin)
    always @(posedge clk)
    begin
        if (reset || fs_allowin)   
        begin
            IF_over <= 1'b0;
        end
        else
        begin
            IF_over <= fs_valid;
        end
    end




assign inst_sram_en    = to_fs_valid && fs_allowin ;     ///to_fs_valid && fs_allowin  去掉fs_allowin
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

/*assign fs_inst =  inst_buff_enable ?  fs_inst_r : 
                  inst_sram_rdata;  
    */   
assign fs_inst   = inst_buff_enable  ? fs_inst_r : 
                   inst_sram_rdata;
/*             
assign fs_inst         = (need_stall && !is_two_stalls)  ? fs_inst_r :
                         (need_stall && is_two_stalls)  ? fs_inst_r_buffer : 
                         (br_taken && !need_stall && br_is_one_stalls) ? fs_inst_brtaken :
                          inst_buff_enable               ? fs_inst_r  :
                   //      (!if_stall && forward_stall )   ? fs_inst_r :
                                    inst_sram_rdata;
*/
endmodule
