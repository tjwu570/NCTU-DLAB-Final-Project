//
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "image.dat"
// Each line defines a cell value. The number of data in image.dat
// must match the size of the sram block exactly.

module sram
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 19, RAM_SIZE = 65536)
 (input clk, input we, input en,
  input  [9:0] x, input [9:0] y,input  [DATA_WIDTH-1 : 0] data_i,output reg [DATA_WIDTH-1 : 0] data_o, input [3:0] b_x,input [3:0] b_y,
  input is_black,input color_change,
  input is_food, input food_small,
  input is_snake, input is_snake_head, input is_bumped,
  input is_block, input block_transparent);

// Declaration of the memory cells
 (* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

integer idx;

initial begin
    $readmemh("images.mem", RAM);
end

localparam back_addr = 0;
localparam back_rev_addr = 230400;
localparam food_big_addr = 460800;
localparam food_small_addr = 460900;
localparam food_rev_big_addr = 461000;
localparam food_rev_small_addr = 461100;
localparam block_addr = 461200;
localparam snakehead_addr = 461300;
localparam snake_addr = 461400;
localparam snakehead_rev_addr = 461500;
localparam snake_rev_addr = 461600;
localparam zero_addr = 461700;
localparam one_addr = 466700;
localparam two_addr = 471700;
localparam three_addr = 476700;
localparam four_addr = 481700;
localparam five_addr = 486700;
localparam six_addr = 491700;
localparam seven_addr = 496700;
localparam eight_addr = 501700;
localparam nine_addr = 506700;

reg [32:0] addr;
// ------------------------------------
// SRAM read operation
// ------------------------------------
always@(posedge clk) begin
  if (en & we) data_o <= data_i;
  else if(is_black) data_o <= 12'h000;
  else begin
    if(color_change) begin
        if(is_snake_head) begin
            if(is_bumped) data_o <= RAM[snakehead_rev_addr + (b_y*10) + b_x];
            else data_o <= RAM[snakehead_addr + (b_y*10) + b_x];
        end
        else if(is_snake) begin
            if(is_bumped) data_o <= RAM[snake_rev_addr + (b_y*10) + b_x];
            else data_o <= RAM[snake_addr + (b_y*10) + b_x];
        end
        else if(is_food) begin
            if(~food_small)data_o <= RAM[food_big_addr + (b_y*10) + b_x];
            else data_o <= RAM[food_small_addr + (b_y*10) + b_x];
        end
        else if(is_block && ~block_transparent) begin
            data_o <= RAM[block_addr + (b_y*10) + b_x];
        end
        else data_o <= RAM[back_addr+480*y+x];
    end
    else begin
        if(is_snake_head) begin
            if(is_bumped) data_o <= RAM[snakehead_rev_addr + (b_y*10) + b_x];
            else data_o <= RAM[snakehead_addr + (b_y*10) + b_x];
        end
        else if(is_snake) begin
            if(is_bumped) data_o <= RAM[snake_rev_addr + (b_y*10) + b_x];
            else data_o <= RAM[snake_addr + (b_y*10) + b_x];
        end
        else if(is_food) begin
            if(~food_small)data_o <= RAM[food_rev_big_addr + (b_y*10) + b_x];
            else data_o <= RAM[food_rev_small_addr + (b_y*10) + b_x];
        end
        else if(is_block && ~block_transparent) begin
            data_o <= RAM[block_addr + (b_y*10) + b_x];
        end
        else data_o <= RAM[back_rev_addr+480*y+x];
    end
  end
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
 always@(posedge clk)
 begin
   if (en & we)
     RAM[addr] <= data_i;
 end

endmodule

/* // original module, not supposed to use 
module sram_background
 (input clk, input we, input en,
  input  is_black,
  input color_change,
  input  [12-1 : 0] data_i,
  output reg [12-1 : 0] data_o,
  input is_food,
  input is_snake,
  input is_snake_head, 
  input is_bumped,
  input is_block, input block_transparent);

integer idx;

always@(posedge clk)
begin
  if (en & we) begin
      data_o <= data_i;
  end
  else if(is_black) begin
      data_o <= 12'h0;
  end
  else if(color_change) begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF0F;
        else data_o <= 12'h080;
      end
      else if(is_food) begin 
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hBEF;
      end
  end
  else  begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if(is_food) begin
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hFEB;
      end
  end
end

endmodule
*/